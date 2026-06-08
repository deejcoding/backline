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
import type { Listing, ListingCategory, ListingCondition, ListingType, Borough } from '@/lib/types'
import imageCompression from 'browser-image-compression'

// Fetch all listings
export function useListings() {
  return useQuery({
    queryKey: ['listings'],
    queryFn: async (): Promise<Listing[]> => {
      const q = query(collection(db, 'listings'), orderBy('createdAt', 'desc'))
      const snapshot = await getDocs(q)

      return snapshot.docs
        .map((doc) => {
          const data = doc.data()
          return {
            id: doc.id,
            title: data.title,
            description: data.description,
            price: data.price,
            rentPrice: data.rentPrice,
            listingTypes: data.listingTypes || ['Sell'],
            category: data.category,
            condition: data.condition,
            location: data.location,
            borough: data.borough,
            photoURLs: data.photoURLs || [],
            sellerUID: data.sellerUID,
            sellerUsername: data.sellerUsername,
            createdAt: (data.createdAt as Timestamp)?.toDate() || new Date(),
          } as Listing
        })
        .filter((listing) => listing.title && listing.sellerUID)
    },
  })
}

// Fetch single listing
export function useListing(id: string) {
  return useQuery({
    queryKey: ['listing', id],
    queryFn: async (): Promise<Listing | null> => {
      const docSnap = await getDoc(doc(db, 'listings', id))
      if (!docSnap.exists()) return null

      const data = docSnap.data()
      return {
        id: docSnap.id,
        title: data.title,
        description: data.description,
        price: data.price,
        rentPrice: data.rentPrice,
        listingTypes: data.listingTypes || ['Sell'],
        category: data.category,
        condition: data.condition,
        location: data.location,
        borough: data.borough,
        photoURLs: data.photoURLs || [],
        sellerUID: data.sellerUID,
        sellerUsername: data.sellerUsername,
        createdAt: (data.createdAt as Timestamp)?.toDate() || new Date(),
      }
    },
    enabled: !!id,
  })
}

// Fetch user's listings
export function useUserListings(uid: string) {
  return useQuery({
    queryKey: ['listings', 'user', uid],
    queryFn: async (): Promise<Listing[]> => {
      const q = query(
        collection(db, 'listings'),
        where('sellerUID', '==', uid),
        orderBy('createdAt', 'desc')
      )
      const snapshot = await getDocs(q)

      return snapshot.docs.map((doc) => {
        const data = doc.data()
        return {
          id: doc.id,
          title: data.title,
          description: data.description,
          price: data.price,
          rentPrice: data.rentPrice,
          listingTypes: data.listingTypes || ['Sell'],
          category: data.category,
          condition: data.condition,
          location: data.location,
          borough: data.borough,
          photoURLs: data.photoURLs || [],
          sellerUID: data.sellerUID,
          sellerUsername: data.sellerUsername,
          createdAt: (data.createdAt as Timestamp)?.toDate() || new Date(),
        }
      })
    },
    enabled: !!uid,
  })
}

// Upload photos
async function uploadPhotos(files: File[], listingId: string): Promise<string[]> {
  const urls: string[] = []

  for (let i = 0; i < files.length; i++) {
    const file = files[i]

    // Compress image
    const compressed = await imageCompression(file, {
      maxSizeMB: 1,
      maxWidthOrHeight: 1920,
      useWebWorker: true,
    })

    const storageRef = ref(storage, `listing_photos/${listingId}/${i}.jpg`)
    await uploadBytes(storageRef, compressed, { contentType: 'image/jpeg' })
    const url = await getDownloadURL(storageRef)
    urls.push(url)
  }

  return urls
}

// Create listing mutation
interface CreateListingInput {
  title: string
  description: string
  price?: number
  rentPrice?: string
  listingTypes: ListingType[]
  category: ListingCategory
  condition: ListingCondition
  location: string
  borough?: Borough
  photos: File[]
  sellerUID: string
  sellerUsername: string
}

export function useCreateListing() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (input: CreateListingInput) => {
      const listingRef = doc(collection(db, 'listings'))
      const photoURLs = await uploadPhotos(input.photos, listingRef.id)

      const data: any = {
        id: listingRef.id,
        title: input.title,
        description: input.description,
        listingTypes: input.listingTypes,
        category: input.category,
        condition: input.condition,
        location: input.location,
        photoURLs,
        sellerUID: input.sellerUID,
        sellerUsername: input.sellerUsername,
        createdAt: serverTimestamp(),
      }

      if (input.price !== undefined) data.price = input.price
      if (input.rentPrice) data.rentPrice = input.rentPrice
      if (input.borough) data.borough = input.borough

      await addDoc(collection(db, 'listings'), data)
      return listingRef.id
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['listings'] })
    },
  })
}

// Update listing mutation
interface UpdateListingInput {
  id: string
  title: string
  description: string
  price?: number
  rentPrice?: string
  listingTypes: ListingType[]
  category: ListingCategory
  condition: ListingCondition
  location: string
  borough?: Borough
  existingPhotoURLs: string[]
  newPhotos: File[]
}

export function useUpdateListing() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (input: UpdateListingInput) => {
      let photoURLs = input.existingPhotoURLs

      if (input.newPhotos.length > 0) {
        const newURLs = await uploadPhotos(input.newPhotos, input.id)
        photoURLs = [...photoURLs, ...newURLs]
      }

      const data: any = {
        title: input.title,
        description: input.description,
        listingTypes: input.listingTypes,
        category: input.category,
        condition: input.condition,
        location: input.location,
        photoURLs,
      }

      if (input.price !== undefined) {
        data.price = input.price
      }
      if (input.rentPrice) {
        data.rentPrice = input.rentPrice
      }
      if (input.borough) {
        data.borough = input.borough
      }

      await updateDoc(doc(db, 'listings', input.id), data)
    },
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['listings'] })
      queryClient.invalidateQueries({ queryKey: ['listing', variables.id] })
    },
  })
}

// Delete listing mutation
export function useDeleteListing() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (id: string) => {
      await deleteDoc(doc(db, 'listings', id))
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['listings'] })
    },
  })
}
