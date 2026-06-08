'use client'

import Link from 'next/link'
import Image from 'next/image'
import { formatPrice } from '@/lib/types'
import type { Listing } from '@/lib/types'

interface ListingCardProps {
  listing: Listing
}

export function ListingCard({ listing }: ListingCardProps) {
  const hasPrice = listing.price !== undefined && listing.price > 0
  const hasRent = listing.rentPrice && listing.rentPrice.length > 0

  return (
    <Link href={`/market/${listing.id}`} className="block">
      {/* Square photo */}
      <div className="aspect-square bg-white/5 overflow-hidden">
        {listing.photoURLs?.[0] ? (
          <img
            src={listing.photoURLs[0]}
            alt={listing.title}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <span className="text-2xl text-white/20">🎸</span>
          </div>
        )}
      </div>

      {/* Info */}
      <div className="pt-2">
        <h3 className="font-semibold text-sm line-clamp-1">
          {listing.title}
        </h3>

        <div className="flex items-center gap-2 mt-1">
          {hasPrice && (
            <span className="font-mono text-sm font-bold text-signal-green">
              {formatPrice(listing.price!)}
            </span>
          )}
          {hasRent && (
            <span className="font-mono text-xs font-medium text-accent">
              {listing.rentPrice}
            </span>
          )}
          <span className="font-mono text-[10px] text-white/50 tracking-wider">
            {listing.condition}
          </span>
        </div>

        <div className="flex items-center gap-1 mt-1 font-mono text-[11px] text-white/55">
          <span>@{listing.sellerUsername}</span>
          <span className="text-white/40">·</span>
          <span className="truncate">{listing.borough || listing.location}</span>
        </div>
      </div>
    </Link>
  )
}
