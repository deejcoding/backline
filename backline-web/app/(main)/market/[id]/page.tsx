'use client'

import { useState } from 'react'
import { useParams } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, MapPin, X, ChevronLeft, ChevronRight } from 'lucide-react'
import { useListing } from '@/lib/hooks/useListings'
import { useAuthStore } from '@/lib/stores/authStore'
import { Button, Avatar } from '@/components/ui'
import { formatPrice, timeAgo } from '@/lib/types'

export default function ListingDetailPage() {
  const params = useParams()
  const id = Array.isArray(params.id) ? params.id[0] : params.id || ''
  const { isBlocked } = useAuthStore()
  const { data: listing, isLoading } = useListing(id)

  const [selectedPhotoIndex, setSelectedPhotoIndex] = useState(0)
  const [showFullscreen, setShowFullscreen] = useState(false)

  if (isLoading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12 flex items-center justify-center">
        <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!listing) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12 text-center">
        <p className="text-white/50 mb-4">Listing not found</p>
        <Link href="/market"><Button variant="outline">Back to Market</Button></Link>
      </div>
    )
  }

  if (isBlocked(listing.sellerUID)) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12 text-center">
        <p className="text-white/50 mb-4">This user is blocked</p>
        <Link href="/market"><Button variant="outline">Back to Market</Button></Link>
      </div>
    )
  }

  const photos = listing.photoURLs || []

  return (
    <div className="max-w-4xl mx-auto px-4 py-4 pb-24">
      {/* Back */}
      <Link href="/market" className="inline-flex items-center gap-1 text-sm text-white/50 hover:text-white mb-4">
        <ArrowLeft size={16} /> Back
      </Link>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Photos */}
        <div>
          {photos.length > 0 && (
            <>
              <button
                onClick={() => setShowFullscreen(true)}
                className="w-full aspect-square bg-white/5 overflow-hidden mb-2"
              >
                <img src={photos[selectedPhotoIndex]} alt="" className="w-full h-full object-contain" />
              </button>
              {photos.length > 1 && (
                <div className="flex gap-2 overflow-x-auto hide-scrollbar">
                  {photos.map((photo, i) => (
                    <button
                      key={i}
                      onClick={() => setSelectedPhotoIndex(i)}
                      className={`w-16 h-16 flex-shrink-0 overflow-hidden ${i === selectedPhotoIndex ? 'ring-2 ring-accent' : 'opacity-60'}`}
                    >
                      <img src={photo} alt="" className="w-full h-full object-cover" />
                    </button>
                  ))}
                </div>
              )}
            </>
          )}
        </div>

        {/* Details */}
        <div>
          <div className="flex gap-2 mb-2">
            <span className="px-2 py-0.5 bg-accent/20 text-accent font-mono text-[10px] font-bold">{listing.category}</span>
            <span className="px-2 py-0.5 bg-white/10 font-mono text-[10px]">{listing.condition}</span>
          </div>

          <h1 className="text-xl font-bold mb-2">{listing.title}</h1>

          <div className="flex items-baseline gap-2 mb-4">
            {listing.price && (
              <span className="font-mono text-2xl font-bold text-signal-green">{formatPrice(listing.price)}</span>
            )}
            {listing.rentPrice && (
              <span className="font-mono text-sm text-white/50">{listing.rentPrice}</span>
            )}
          </div>

          <div className="flex items-center gap-3 text-sm text-white/60 mb-4">
            <span className="flex items-center gap-1"><MapPin size={14} /> {listing.borough || listing.location}</span>
            <span>{timeAgo(listing.createdAt)}</span>
          </div>

          <p className="text-sm text-white/80 whitespace-pre-wrap mb-6">{listing.description}</p>

          {/* Seller */}
          <div className="flex items-center gap-3 p-3 border border-white/10">
            <Link href={`/u/${listing.sellerUsername}`}>
              <Avatar size="md" />
            </Link>
            <div>
              <p className="text-xs text-white/50">Listed by</p>
              <Link href={`/u/${listing.sellerUsername}`} className="font-mono text-sm hover:text-accent">
                @{listing.sellerUsername}
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* Fullscreen */}
      {showFullscreen && photos.length > 0 && (
        <div className="fixed inset-0 z-50 bg-black/95 flex items-center justify-center" onClick={() => setShowFullscreen(false)}>
          <button onClick={() => setShowFullscreen(false)} className="absolute top-4 right-4 text-white hover:text-accent">
            <X size={24} />
          </button>
          <img src={photos[selectedPhotoIndex]} alt="" className="max-w-full max-h-full object-contain" />
          {photos.length > 1 && (
            <>
              <button
                onClick={(e) => { e.stopPropagation(); setSelectedPhotoIndex((i) => (i === 0 ? photos.length - 1 : i - 1)) }}
                className="absolute left-4 top-1/2 -translate-y-1/2 w-10 h-10 flex items-center justify-center bg-white/10 hover:bg-white/20"
              >
                <ChevronLeft size={20} />
              </button>
              <button
                onClick={(e) => { e.stopPropagation(); setSelectedPhotoIndex((i) => (i === photos.length - 1 ? 0 : i + 1)) }}
                className="absolute right-4 top-1/2 -translate-y-1/2 w-10 h-10 flex items-center justify-center bg-white/10 hover:bg-white/20"
              >
                <ChevronRight size={20} />
              </button>
            </>
          )}
        </div>
      )}
    </div>
  )
}
