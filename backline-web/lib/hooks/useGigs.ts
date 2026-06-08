import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  collection,
  query,
  orderBy,
  getDocs,
  getDoc,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  where,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore'
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage'
import { db, storage } from '@/lib/firebase/config'
import type { ISOPost, ISOCategory, ServiceListing, ServiceCategory, ShowFlyer } from '@/lib/types'
import imageCompression from 'browser-image-compression'

// ============ ISO POSTS ============

export function useIsoPosts() {
  return useQuery({
    queryKey: ['isoPosts'],
    queryFn: async (): Promise<ISOPost[]> => {
      const q = query(collection(db, 'isoPosts'), orderBy('createdAt', 'desc'))
      const snapshot = await getDocs(q)

      return snapshot.docs
        .map((doc) => {
          const data = doc.data()
          return {
            id: doc.id,
            category: data.category,
            roleNeeded: data.roleNeeded || data.role,
            genre: data.genre,
            location: data.location || data.borough,
            timeframe: data.timeframe,
            isOngoing: data.isOngoing,
            budget: data.budget,
            description: data.description,
            posterUID: data.posterUID || data.authorUID,
            posterUsername: data.posterUsername || data.authorUsername,
            createdAt: (data.createdAt as Timestamp)?.toDate() || new Date(),
          } as ISOPost
        })
        .filter((post) => post.posterUID && (post.roleNeeded || post.category))
    },
  })
}

export function useIsoPost(id: string) {
  return useQuery({
    queryKey: ['isoPost', id],
    queryFn: async (): Promise<ISOPost | null> => {
      const docSnap = await getDoc(doc(db, 'isoPosts', id))
      if (!docSnap.exists()) return null

      const data = docSnap.data()
      return {
        id: docSnap.id,
        category: data.category,
        roleNeeded: data.roleNeeded || data.role,
        genre: data.genre,
        location: data.location || data.borough,
        timeframe: data.timeframe,
        isOngoing: data.isOngoing,
        budget: data.budget,
        description: data.description,
        posterUID: data.posterUID || data.authorUID,
        posterUsername: data.posterUsername || data.authorUsername,
        createdAt: (data.createdAt as Timestamp)?.toDate() || new Date(),
      }
    },
    enabled: !!id,
  })
}

interface CreateISOPostInput {
  authorUID: string
  authorUsername: string
  role: string
  genre?: string
  description: string
  budget?: number
  timeframe?: string
  borough?: string
}

export function useCreateISOPost() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (input: CreateISOPostInput) => {
      const data: any = {
        roleNeeded: input.role,
        description: input.description,
        posterUID: input.authorUID,
        posterUsername: input.authorUsername,
        createdAt: serverTimestamp(),
      }

      if (input.genre) data.genre = input.genre
      if (input.budget) data.budget = input.budget
      if (input.timeframe) data.timeframe = input.timeframe
      if (input.borough) data.location = input.borough

      const docRef = await addDoc(collection(db, 'isoPosts'), data)
      return docRef.id
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['isoPosts'] })
    },
  })
}

// Legacy hook name for backwards compatibility
export const useCreateIsoPost = useCreateISOPost

export function useDeleteIsoPost() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (id: string) => {
      await deleteDoc(doc(db, 'isoPosts', id))
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['isoPosts'] })
    },
  })
}

// ============ SERVICE LISTINGS ============

export function useServiceListings() {
  return useQuery({
    queryKey: ['serviceListings'],
    queryFn: async (): Promise<ServiceListing[]> => {
      const q = query(collection(db, 'serviceListings'), orderBy('createdAt', 'desc'))
      const snapshot = await getDocs(q)

      return snapshot.docs
        .map((doc) => {
          const data = doc.data()
          return {
            id: doc.id,
            title: data.title,
            category: data.category,
            description: data.description,
            portfolioURL: data.portfolioURL,
            rate: data.rate,
            rateType: data.rateType,
            borough: data.borough,
            sellerUID: data.sellerUID || data.authorUID,
            sellerUsername: data.sellerUsername || data.authorUsername,
            createdAt: (data.createdAt as Timestamp)?.toDate() || new Date(),
          } as ServiceListing
        })
        .filter((service) => service.sellerUID && service.title)
    },
  })
}

export function useServiceListing(id: string) {
  return useQuery({
    queryKey: ['serviceListing', id],
    queryFn: async (): Promise<ServiceListing | null> => {
      const docSnap = await getDoc(doc(db, 'serviceListings', id))
      if (!docSnap.exists()) return null

      const data = docSnap.data()
      return {
        id: docSnap.id,
        title: data.title,
        category: data.category,
        description: data.description,
        portfolioURL: data.portfolioURL,
        rate: data.rate,
        rateType: data.rateType,
        borough: data.borough,
        sellerUID: data.sellerUID || data.authorUID,
        sellerUsername: data.sellerUsername || data.authorUsername,
        createdAt: (data.createdAt as Timestamp)?.toDate() || new Date(),
      }
    },
    enabled: !!id,
  })
}

interface CreateServiceInput {
  authorUID: string
  authorUsername: string
  title: string
  category: string
  description: string
  rate?: number
  rateType?: 'hourly' | 'flat' | 'negotiable'
  portfolioURL?: string
  borough?: string
}

export function useCreateServiceListing() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (input: CreateServiceInput) => {
      const data: any = {
        title: input.title,
        category: input.category,
        description: input.description,
        sellerUID: input.authorUID,
        sellerUsername: input.authorUsername,
        createdAt: serverTimestamp(),
      }

      if (input.rate) data.rate = input.rate
      if (input.rateType) data.rateType = input.rateType
      if (input.portfolioURL) data.portfolioURL = input.portfolioURL
      if (input.borough) data.borough = input.borough

      const docRef = await addDoc(collection(db, 'serviceListings'), data)
      return docRef.id
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['serviceListings'] })
    },
  })
}

export function useDeleteServiceListing() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (id: string) => {
      await deleteDoc(doc(db, 'serviceListings', id))
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['serviceListings'] })
    },
  })
}

// ============ SHOW FLYERS ============

export function useShowFlyers() {
  return useQuery({
    queryKey: ['showFlyers'],
    queryFn: async (): Promise<ShowFlyer[]> => {
      const q = query(collection(db, 'showFlyers'), orderBy('createdAt', 'desc'))
      const snapshot = await getDocs(q)

      return snapshot.docs
        .map((doc) => {
          const data = doc.data()
          return {
            id: doc.id,
            imageURL: data.imageURL,
            title: data.title,
            venue: data.venue,
            eventDate: data.eventDate ? (data.eventDate as Timestamp).toDate() : undefined,
            description: data.description,
            borough: data.borough,
            posterUID: data.posterUID || data.authorUID,
            posterUsername: data.posterUsername || data.authorUsername,
            createdAt: (data.createdAt as Timestamp)?.toDate() || new Date(),
            ticketURL: data.ticketURL,
          } as ShowFlyer
        })
        .filter((flyer) => flyer.posterUID)
    },
  })
}

export function useShowFlyer(id: string) {
  return useQuery({
    queryKey: ['showFlyer', id],
    queryFn: async (): Promise<ShowFlyer | null> => {
      const docSnap = await getDoc(doc(db, 'showFlyers', id))
      if (!docSnap.exists()) return null

      const data = docSnap.data()
      return {
        id: docSnap.id,
        imageURL: data.imageURL,
        title: data.title,
        venue: data.venue,
        eventDate: data.eventDate ? (data.eventDate as Timestamp).toDate() : undefined,
        description: data.description,
        borough: data.borough,
        posterUID: data.posterUID || data.authorUID,
        posterUsername: data.posterUsername || data.authorUsername,
        createdAt: (data.createdAt as Timestamp)?.toDate() || new Date(),
        ticketURL: data.ticketURL,
      }
    },
    enabled: !!id,
  })
}

interface CreateShowFlyerInput {
  authorUID: string
  authorUsername: string
  title: string
  venue: string
  eventDate: Date
  description?: string
  ticketURL?: string
  borough?: string
  photos?: File[]
}

export function useCreateShowFlyer() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (input: CreateShowFlyerInput) => {
      const flyerId = doc(collection(db, 'showFlyers')).id
      let imageURL: string | undefined

      // Upload flyer image if provided
      if (input.photos && input.photos.length > 0) {
        const compressed = await imageCompression(input.photos[0], {
          maxSizeMB: 1,
          maxWidthOrHeight: 1920,
          useWebWorker: true,
        })

        const storageRef = ref(storage, `flyer_photos/${flyerId}.jpg`)
        await uploadBytes(storageRef, compressed, { contentType: 'image/jpeg' })
        imageURL = await getDownloadURL(storageRef)
      }

      const data: any = {
        title: input.title,
        venue: input.venue,
        eventDate: Timestamp.fromDate(input.eventDate),
        posterUID: input.authorUID,
        posterUsername: input.authorUsername,
        createdAt: serverTimestamp(),
      }

      if (imageURL) data.imageURL = imageURL
      if (input.description) data.description = input.description
      if (input.ticketURL) data.ticketURL = input.ticketURL
      if (input.borough) data.borough = input.borough

      await addDoc(collection(db, 'showFlyers'), data)
      return flyerId
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['showFlyers'] })
    },
  })
}

export function useDeleteShowFlyer() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (id: string) => {
      await deleteDoc(doc(db, 'showFlyers', id))
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['showFlyers'] })
    },
  })
}
