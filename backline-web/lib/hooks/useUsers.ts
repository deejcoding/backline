import { useQuery } from '@tanstack/react-query'
import {
  collection,
  query,
  getDocs,
  getDoc,
  doc,
  where,
} from 'firebase/firestore'
import { db } from '@/lib/firebase/config'
import type { UserProfile } from '@/lib/types'

export function useUsers() {
  return useQuery({
    queryKey: ['users'],
    queryFn: async (): Promise<UserProfile[]> => {
      const snapshot = await getDocs(collection(db, 'users'))

      return snapshot.docs
        .map((doc) => {
          const data = doc.data()
          if (!data.username) return null

          return {
            id: doc.id,
            username: data.username,
            displayName: data.displayName,
            profilePhotoURL: data.profilePhotoURL,
            roles: data.roles || [],
            genres: data.genres || [],
            bio: data.bio,
            neighborhood: data.neighborhood,
            instagramHandle: data.instagramHandle,
            musicProjects: data.musicProjects || [],
            featuredProjects: data.featuredProjects || [],
          } as UserProfile
        })
        .filter(Boolean) as UserProfile[]
    },
  })
}

export function useUser(uid: string) {
  return useQuery({
    queryKey: ['user', uid],
    queryFn: async (): Promise<UserProfile | null> => {
      const docSnap = await getDoc(doc(db, 'users', uid))
      if (!docSnap.exists()) return null

      const data = docSnap.data()
      return {
        id: docSnap.id,
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
      }
    },
    enabled: !!uid,
  })
}

export function useUserByUsername(username: string) {
  return useQuery({
    queryKey: ['user', 'username', username],
    queryFn: async (): Promise<UserProfile | null> => {
      const q = query(
        collection(db, 'users'),
        where('username', '==', username.toLowerCase())
      )
      const snapshot = await getDocs(q)

      if (snapshot.empty) return null

      const doc = snapshot.docs[0]
      const data = doc.data()

      return {
        id: doc.id,
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
      }
    },
    enabled: !!username,
  })
}
