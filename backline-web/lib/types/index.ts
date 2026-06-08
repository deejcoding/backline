// User Profile
export interface UserProfile {
  id: string
  username: string
  displayName?: string
  profilePhotoURL?: string
  roles: string[]
  genres: string[]
  bio?: string
  neighborhood?: string
  instagramHandle?: string
  musicProjects?: MusicProject[]
  featuredProjects?: SpotifyTrack[]
  blockedUsers?: string[]
  allowMessagesFrom?: 'anyone' | 'connections'
  referralCode?: string
  onboardingComplete?: boolean
}

export interface MusicProject {
  id: string
  title: string
  url: string
  platform: MusicPlatform
  thumbnailURL?: string
}

export type MusicPlatform = 'spotify' | 'soundcloud' | 'bandcamp' | 'youtube' | 'apple'

export interface SpotifyTrack {
  id: string
  name: string
  artistName: string
  albumName: string
  albumImageURL?: string
  previewURL?: string
  externalURL: string
  itemType?: SpotifyItemType
}

export type SpotifyItemType = 'track' | 'album' | 'artist'

// Listing Categories
export type ListingCategory =
  | 'Guitars'
  | 'Amps'
  | 'Synthesizers'
  | 'Stringed Instruments'
  | 'Drums & Percussion'
  | 'Microphones'
  | 'Accessories'
  | 'Miscellaneous'

export const LISTING_CATEGORIES: ListingCategory[] = [
  'Guitars',
  'Amps',
  'Synthesizers',
  'Stringed Instruments',
  'Drums & Percussion',
  'Microphones',
  'Accessories',
  'Miscellaneous',
]

export type ListingCondition = 'New' | 'Like New' | 'Good' | 'Fair' | 'Poor'

export const LISTING_CONDITIONS: ListingCondition[] = [
  'New',
  'Like New',
  'Good',
  'Fair',
  'Poor',
]

export type ListingType = 'Sell' | 'Rent'

export type Borough = 'Manhattan' | 'Brooklyn' | 'Queens' | 'Bronx' | 'Staten Island'

export const BOROUGHS: Borough[] = [
  'Manhattan',
  'Brooklyn',
  'Queens',
  'Bronx',
  'Staten Island',
]

export interface Listing {
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
  photoURLs: string[]
  sellerUID: string
  sellerUsername: string
  createdAt: Date
}

// Service Categories
export type ServiceCategory =
  | 'Gigging Musician'
  | 'Repair'
  | 'Production'
  | 'Design'
  | 'Live Sound'

export const SERVICE_CATEGORIES: ServiceCategory[] = [
  'Gigging Musician',
  'Repair',
  'Production',
  'Design',
  'Live Sound',
]

export interface ServiceListing {
  id: string
  title: string
  category: ServiceCategory | string
  description: string
  portfolioURL?: string
  rate?: number | string
  rateType?: 'hourly' | 'flat' | 'negotiable'
  borough?: string
  sellerUID: string
  sellerUsername: string
  createdAt: Date
}

// ISO Categories
export type ISOCategory =
  | 'Gig'
  | 'Bandmate'
  | 'Recording'
  | 'Production'
  | 'Repair'
  | 'Lessons'
  | 'Practice Space'

export const ISO_CATEGORIES: ISOCategory[] = [
  'Gig',
  'Bandmate',
  'Recording',
  'Production',
  'Repair',
  'Lessons',
  'Practice Space',
]

export interface ISOPost {
  id: string
  category?: ISOCategory
  roleNeeded: string
  genre?: string
  location?: string
  timeframe?: string
  isOngoing?: boolean
  budget?: number | string
  description: string
  posterUID: string
  posterUsername: string
  createdAt: Date
}

// Show Flyers
export interface ShowFlyer {
  id: string
  imageURL?: string
  title: string
  venue?: string
  eventDate?: Date
  description?: string
  borough?: string
  posterUID: string
  posterUsername: string
  createdAt: Date
  ticketURL?: string
}

// Connections
export type ConnectionStatus = 'pending' | 'accepted' | 'rejected'

export interface Connection {
  id: string
  fromUID: string
  toUID: string
  participants: string[]
  participantUsernames: Record<string, string>
  status: ConnectionStatus
  createdAt: Date
  respondedAt?: Date
}

export type ConnectionStatusResult =
  | { type: 'none' }
  | { type: 'pendingOutgoing'; connection: Connection }
  | { type: 'pendingIncoming'; connection: Connection }
  | { type: 'connected'; connection: Connection }

// Messaging
export interface Conversation {
  id: string
  participants: string[]
  participantUsernames: Record<string, string>
  lastMessage: string
  lastMessageAt: Date
  lastMessageSenderUID: string
  lastReadAt: Record<string, Date>
}

export interface Message {
  id: string
  senderUID: string
  text: string
  sentAt: Date
}

// Helpers
export function toDate(value: any): Date {
  if (!value) return new Date()
  if (value instanceof Date) return value
  if (value?.toDate) return value.toDate() // Firestore Timestamp
  if (value?.seconds) return new Date(value.seconds * 1000) // Raw timestamp object
  if (typeof value === 'string' || typeof value === 'number') return new Date(value)
  return new Date()
}

export function timeAgo(date: Date | any): string {
  const d = toDate(date)
  const seconds = Math.floor((Date.now() - d.getTime()) / 1000)
  const minutes = Math.floor(seconds / 60)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)

  if (minutes < 1) return 'just now'
  if (minutes < 60) return `${minutes}m ago`
  if (hours < 24) return `${hours}h ago`
  return `${days}d ago`
}

export function formatPrice(price: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(price)
}
