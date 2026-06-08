import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import {
  User,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut as firebaseSignOut,
  sendPasswordResetEmail,
  sendEmailVerification,
  GoogleAuthProvider,
  signInWithPopup,
  OAuthProvider,
} from 'firebase/auth'
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  query,
  collection,
  where,
  getDocs,
  arrayUnion,
  arrayRemove,
  serverTimestamp,
  deleteField,
} from 'firebase/firestore'
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage'
import { auth, db, storage } from '@/lib/firebase/config'
import type { UserProfile, MusicProject, SpotifyTrack } from '@/lib/types'
import { isValidUsername } from '@/lib/utils/profanityFilter'

interface AuthState {
  user: User | null
  profile: UserProfile | null
  isLoading: boolean
  isGuestMode: boolean
  needsUsername: boolean
  needsReferralCode: boolean
  needsOnboarding: boolean
  onboardingStep: number
  errorMessage: string | null

  // Computed
  isAuthenticated: boolean
  profileCompleteness: number
  canInteract: boolean

  // Actions
  setUser: (user: User | null) => void
  setProfile: (profile: UserProfile | null) => void
  setError: (error: string | null) => void
  setLoading: (loading: boolean) => void

  // Auth methods
  signIn: (emailOrUsername: string, password: string) => Promise<void>
  signUp: (email: string, password: string, username: string, referralCode: string) => Promise<void>
  signInWithGoogle: () => Promise<void>
  signInWithApple: () => Promise<void>
  resetPassword: (email: string) => Promise<void>
  signOut: () => Promise<void>

  // Profile methods
  fetchProfile: (uid: string) => Promise<void>
  updateProfile: (updates: Partial<UserProfile>) => Promise<void>
  uploadProfilePhoto: (file: File) => Promise<void>
  updateBio: (bio: string) => Promise<void>
  updateRoles: (roles: string[]) => Promise<void>
  updateGenres: (genres: string[]) => Promise<void>
  updateNeighborhood: (neighborhood: string | null) => Promise<void>
  completeOnboarding: () => Promise<void>
  completeSocialRegistration: (username: string, referralCode: string) => Promise<void>

  // Block methods
  blockUser: (uid: string) => Promise<void>
  unblockUser: (uid: string) => Promise<void>
  isBlocked: (uid: string) => boolean

  // Guest mode
  enterGuestMode: () => void
  exitGuestMode: () => void
}

function generateReferralCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  let code = ''
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return code
}

async function validateReferralCode(code: string): Promise<boolean> {
  const trimmed = code.trim().toUpperCase()
  if (!trimmed) return false

  // Hardcoded master codes
  const masterCodes = ['BACKLINE2026', 'POTLUCK2026']
  if (masterCodes.includes(trimmed)) return true

  // Check Firestore masterCodes collection
  try {
    const masterDoc = await getDoc(doc(db, 'masterCodes', trimmed))
    if (masterDoc.exists()) {
      const data = masterDoc.data()
      if (data?.active !== false) return true
    }
  } catch {
    // Continue to user codes check
  }

  // Check user referral codes
  try {
    const q = query(collection(db, 'users'), where('referralCode', '==', trimmed))
    const snapshot = await getDocs(q)
    return !snapshot.empty
  } catch {
    return false
  }
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      profile: null,
      isLoading: false,
      isGuestMode: false,
      needsUsername: false,
      needsReferralCode: false,
      needsOnboarding: false,
      onboardingStep: 0,
      errorMessage: null,

      get isAuthenticated() {
        return get().user !== null
      },

      get profileCompleteness() {
        const profile = get().profile
        if (!profile) return 0
        let score = 0
        if (profile.profilePhotoURL) score += 25
        if (profile.bio) score += 20
        if (profile.musicProjects?.length || profile.featuredProjects?.length) score += 15
        if (profile.roles?.length) score += 15
        if (profile.genres?.length) score += 15
        if (profile.neighborhood) score += 10
        return score
      },

      get canInteract() {
        return get().profileCompleteness >= 80
      },

      setUser: (user) => set({ user }),
      setProfile: (profile) => set({ profile }),
      setError: (errorMessage) => set({ errorMessage }),
      setLoading: (isLoading) => set({ isLoading }),

      signIn: async (emailOrUsername, password) => {
        set({ isLoading: true, errorMessage: null })
        try {
          let loginEmail = emailOrUsername.trim()

          // If not an email, look up by username
          if (!loginEmail.includes('@')) {
            const q = query(
              collection(db, 'users'),
              where('username', '==', loginEmail.toLowerCase())
            )
            const snapshot = await getDocs(q)
            if (snapshot.empty) {
              throw new Error('No account found with that username')
            }
            loginEmail = snapshot.docs[0].data().email
          }

          const result = await signInWithEmailAndPassword(auth, loginEmail, password)
          set({ user: result.user })
          await get().fetchProfile(result.user.uid)
        } catch (error: any) {
          set({ errorMessage: error.message })
        } finally {
          set({ isLoading: false })
        }
      },

      signUp: async (email, password, username, referralCode) => {
        set({ isLoading: true, errorMessage: null })
        const trimmedUsername = username.toLowerCase()
        const trimmedReferral = referralCode.trim().toUpperCase()

        // Validate username
        const validation = isValidUsername(trimmedUsername)
        if (!validation.valid) {
          set({ errorMessage: validation.error, isLoading: false })
          return
        }

        try {
          // Create the account first
          const result = await createUserWithEmailAndPassword(auth, email, password)

          // Validate referral code (now authenticated)
          const isReferralValid = await validateReferralCode(trimmedReferral)
          if (!isReferralValid) {
            await result.user.delete()
            set({ errorMessage: 'Invalid referral code', isLoading: false })
            return
          }

          // Check username uniqueness
          const usernameQuery = query(
            collection(db, 'users'),
            where('username', '==', trimmedUsername)
          )
          const usernameSnapshot = await getDocs(usernameQuery)
          if (!usernameSnapshot.empty) {
            await result.user.delete()
            set({ errorMessage: 'That username is already taken', isLoading: false })
            return
          }

          const newReferralCode = generateReferralCode()

          // Create user document
          await setDoc(doc(db, 'users', result.user.uid), {
            username: trimmedUsername,
            email: email,
            referralCode: newReferralCode,
            referredBy: trimmedReferral,
          })

          // Send verification email
          await sendEmailVerification(result.user)

          set({
            user: result.user,
            needsOnboarding: true,
            profile: {
              id: result.user.uid,
              username: trimmedUsername,
              roles: [],
              genres: [],
              referralCode: newReferralCode,
            },
          })
        } catch (error: any) {
          set({ errorMessage: error.message })
        } finally {
          set({ isLoading: false })
        }
      },

      signInWithGoogle: async () => {
        set({ isLoading: true, errorMessage: null })
        try {
          const provider = new GoogleAuthProvider()
          const result = await signInWithPopup(auth, provider)
          set({ user: result.user })

          // Check if user doc exists
          const userDoc = await getDoc(doc(db, 'users', result.user.uid))
          if (!userDoc.exists()) {
            // New user - create doc
            await setDoc(doc(db, 'users', result.user.uid), {
              email: result.user.email || '',
              displayName: result.user.displayName || '',
            })
            set({ needsUsername: true, needsReferralCode: true })
          } else {
            await get().fetchProfile(result.user.uid)
          }
        } catch (error: any) {
          set({ errorMessage: error.message })
        } finally {
          set({ isLoading: false })
        }
      },

      signInWithApple: async () => {
        set({ isLoading: true, errorMessage: null })
        try {
          const provider = new OAuthProvider('apple.com')
          provider.addScope('email')
          provider.addScope('name')
          const result = await signInWithPopup(auth, provider)
          set({ user: result.user })

          const userDoc = await getDoc(doc(db, 'users', result.user.uid))
          if (!userDoc.exists()) {
            await setDoc(doc(db, 'users', result.user.uid), {
              email: result.user.email || '',
              displayName: result.user.displayName || '',
            })
            set({ needsUsername: true, needsReferralCode: true })
          } else {
            await get().fetchProfile(result.user.uid)
          }
        } catch (error: any) {
          set({ errorMessage: error.message })
        } finally {
          set({ isLoading: false })
        }
      },

      resetPassword: async (email) => {
        set({ isLoading: true, errorMessage: null })
        try {
          await sendPasswordResetEmail(auth, email)
          set({ errorMessage: 'Password reset email sent. Check your inbox.' })
        } catch (error: any) {
          set({ errorMessage: error.message })
        } finally {
          set({ isLoading: false })
        }
      },

      signOut: async () => {
        set({ isGuestMode: false })
        try {
          await firebaseSignOut(auth)
          set({
            user: null,
            profile: null,
            needsUsername: false,
            needsOnboarding: false,
            onboardingStep: 0,
          })
        } catch (error: any) {
          set({ errorMessage: error.message })
        }
      },

      fetchProfile: async (uid) => {
        try {
          const docSnap = await getDoc(doc(db, 'users', uid))
          if (!docSnap.exists()) return

          const data = docSnap.data()
          const profile: UserProfile = {
            id: uid,
            username: data.username || '',
            displayName: data.displayName,
            profilePhotoURL: data.profilePhotoURL,
            roles: data.roles || [],
            genres: data.genres || [],
            bio: data.bio,
            neighborhood: data.neighborhood,
            instagramHandle: data.instagramHandle,
            musicProjects: data.musicProjects || [],
            featuredProjects: data.featuredProjects || [],
            blockedUsers: data.blockedUsers || [],
            allowMessagesFrom: data.allowMessagesFrom || 'anyone',
            referralCode: data.referralCode,
            onboardingComplete: data.onboardingComplete,
          }

          set({ profile })

          // Check if needs username
          if (!profile.username) {
            set({ needsUsername: true })
          }

          // Check if needs referral
          if (!data.referralCode && !data.onboardingComplete) {
            set({ needsReferralCode: true })
          }

          // Check if needs onboarding
          if (!data.onboardingComplete && !get().needsUsername && !get().needsReferralCode) {
            set({ needsOnboarding: true })
          }
        } catch (error) {
          console.error('Error fetching profile:', error)
        }
      },

      updateProfile: async (updates) => {
        const { user, profile } = get()
        if (!user || !profile) return

        try {
          await updateDoc(doc(db, 'users', user.uid), updates as any)
          set({ profile: { ...profile, ...updates } })
        } catch (error: any) {
          set({ errorMessage: error.message })
        }
      },

      uploadProfilePhoto: async (file) => {
        const { user } = get()
        if (!user) return

        try {
          const storageRef = ref(storage, `profile_photos/${user.uid}.jpg`)
          await uploadBytes(storageRef, file, { contentType: 'image/jpeg' })
          const url = await getDownloadURL(storageRef)
          await get().updateProfile({ profilePhotoURL: url })
        } catch (error: any) {
          set({ errorMessage: error.message })
        }
      },

      updateBio: async (bio) => {
        await get().updateProfile({ bio })
      },

      updateRoles: async (roles) => {
        await get().updateProfile({ roles })
      },

      updateGenres: async (genres) => {
        await get().updateProfile({ genres })
      },

      updateNeighborhood: async (neighborhood) => {
        const { user } = get()
        if (!user) return

        try {
          if (neighborhood) {
            await updateDoc(doc(db, 'users', user.uid), { neighborhood })
          } else {
            await updateDoc(doc(db, 'users', user.uid), { neighborhood: deleteField() })
          }
          set((state) => ({
            profile: state.profile ? { ...state.profile, neighborhood: neighborhood || undefined } : null,
          }))
        } catch (error: any) {
          set({ errorMessage: error.message })
        }
      },

      completeOnboarding: async () => {
        const { user } = get()
        if (!user) return

        try {
          await updateDoc(doc(db, 'users', user.uid), { onboardingComplete: true })
          set({ needsOnboarding: false, onboardingStep: 0 })
        } catch (error: any) {
          set({ errorMessage: error.message })
        }
      },

      completeSocialRegistration: async (username, referralCode) => {
        const { user, needsUsername, needsReferralCode } = get()
        if (!user) return

        set({ isLoading: true, errorMessage: null })
        const trimmedUsername = username.toLowerCase()
        const trimmedReferral = referralCode.trim().toUpperCase()

        if (needsUsername) {
          const validation = isValidUsername(trimmedUsername)
          if (!validation.valid) {
            set({ errorMessage: validation.error, isLoading: false })
            return
          }

          // Check username uniqueness
          const q = query(collection(db, 'users'), where('username', '==', trimmedUsername))
          const snapshot = await getDocs(q)
          if (!snapshot.empty) {
            set({ errorMessage: 'That username is already taken', isLoading: false })
            return
          }
        }

        if (needsReferralCode) {
          const isValid = await validateReferralCode(trimmedReferral)
          if (!isValid) {
            set({ errorMessage: 'Invalid referral code', isLoading: false })
            return
          }
        }

        try {
          const updates: any = {}

          if (needsUsername) {
            updates.username = trimmedUsername
          }

          if (needsReferralCode) {
            updates.referralCode = generateReferralCode()
            updates.referredBy = trimmedReferral
          }

          await updateDoc(doc(db, 'users', user.uid), updates)

          set({
            needsUsername: false,
            needsReferralCode: false,
          })

          // Check if onboarding is needed
          const docSnap = await getDoc(doc(db, 'users', user.uid))
          const onboardingComplete = docSnap.data()?.onboardingComplete
          set({ needsOnboarding: !onboardingComplete })

          await get().fetchProfile(user.uid)
        } catch (error: any) {
          set({ errorMessage: error.message })
        } finally {
          set({ isLoading: false })
        }
      },

      blockUser: async (uid) => {
        const { user, profile } = get()
        if (!user || !profile || uid === user.uid) return

        try {
          await updateDoc(doc(db, 'users', user.uid), {
            blockedUsers: arrayUnion(uid),
          })
          set({
            profile: {
              ...profile,
              blockedUsers: [...(profile.blockedUsers || []), uid],
            },
          })
        } catch (error: any) {
          set({ errorMessage: error.message })
        }
      },

      unblockUser: async (uid) => {
        const { user, profile } = get()
        if (!user || !profile) return

        try {
          await updateDoc(doc(db, 'users', user.uid), {
            blockedUsers: arrayRemove(uid),
          })
          set({
            profile: {
              ...profile,
              blockedUsers: (profile.blockedUsers || []).filter((id) => id !== uid),
            },
          })
        } catch (error: any) {
          set({ errorMessage: error.message })
        }
      },

      isBlocked: (uid) => {
        const profile = get().profile
        return profile?.blockedUsers?.includes(uid) || false
      },

      enterGuestMode: () => set({ isGuestMode: true }),
      exitGuestMode: () => set({ isGuestMode: false }),
    }),
    {
      name: 'backline-auth',
      partialize: (state) => ({
        isGuestMode: state.isGuestMode,
      }),
    }
  )
)
