'use client'

import { useState, useMemo } from 'react'
import Link from 'next/link'
import { ArrowLeft } from 'lucide-react'
import { useListings } from '@/lib/hooks/useListings'
import { useAuthStore } from '@/lib/stores/authStore'
import { formatPrice } from '@/lib/types'
import { LISTING_CATEGORIES } from '@/lib/types'
import type { ListingCategory } from '@/lib/types'
import clsx from 'clsx'

export default function MarketPage() {
  const { isBlocked } = useAuthStore()
  const { data: listings, isLoading } = useListings()

  const [search, setSearch] = useState('')
  const [category, setCategory] = useState<ListingCategory | null>(null)

  const filteredListings = useMemo(() => {
    if (!listings) return []
    return listings.filter((listing) => {
      if (isBlocked(listing.sellerUID)) return false
      if (category && listing.category !== category) return false
      if (search) {
        const q = search.toLowerCase()
        return (
          listing.title.toLowerCase().includes(q) ||
          listing.description?.toLowerCase().includes(q)
        )
      }
      return true
    })
  }, [listings, category, search, isBlocked])

  return (
    <div className="max-w-6xl mx-auto px-4 py-4 pb-24">
      {/* Back */}
      <Link href="/" className="inline-flex items-center gap-1 text-sm text-white/50 hover:text-white mb-4">
        <ArrowLeft size={16} /> Home
      </Link>

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center gap-4 mb-4">
        <h1 className="text-lg font-bold">Marketplace</h1>
        <input
          type="text"
          placeholder="Search gear..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="flex-1 max-w-md px-3 py-2 bg-white/5 border border-white/10 text-sm placeholder:text-white/30 focus:outline-none focus:border-accent"
        />
      </div>

      {/* Category filters */}
      <div className="flex flex-wrap gap-2 mb-4 pb-4 border-b border-white/10">
        <FilterChip
          label="All"
          isSelected={category === null}
          onClick={() => setCategory(null)}
        />
        {LISTING_CATEGORIES.map((cat) => (
          <FilterChip
            key={cat}
            label={cat}
            isSelected={category === cat}
            onClick={() => setCategory(cat)}
          />
        ))}
      </div>

      {/* Results count */}
      <p className="text-xs text-white/40 mb-4">
        {filteredListings.length} {filteredListings.length === 1 ? 'listing' : 'listings'}
      </p>

      {/* Grid */}
      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filteredListings.length > 0 ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
          {filteredListings.map((listing) => (
            <Link key={listing.id} href={`/market/${listing.id}`} className="group">
              <div className="aspect-square bg-white/5 overflow-hidden mb-2">
                {listing.photoURLs?.[0] ? (
                  <img
                    src={listing.photoURLs[0]}
                    alt=""
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                    loading="lazy"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-white/20">
                    🎸
                  </div>
                )}
              </div>
              <p className="text-sm font-medium truncate">{listing.title}</p>
              <div className="flex items-center gap-2 mt-0.5">
                {listing.price && (
                  <span className="font-mono text-sm font-bold text-signal-green">
                    {formatPrice(listing.price)}
                  </span>
                )}
                {listing.rentPrice && (
                  <span className="font-mono text-[10px] text-accent">{listing.rentPrice}</span>
                )}
              </div>
              <p className="font-mono text-[10px] text-white/40 mt-0.5">
                {listing.condition} · {listing.borough || listing.location}
              </p>
            </Link>
          ))}
        </div>
      ) : (
        <p className="text-center py-12 text-sm text-white/40">
          {search || category ? 'No listings found' : 'No listings yet'}
        </p>
      )}
    </div>
  )
}

function FilterChip({
  label,
  isSelected,
  onClick,
}: {
  label: string
  isSelected: boolean
  onClick: () => void
}) {
  return (
    <button
      onClick={onClick}
      className={clsx(
        'px-2.5 py-1 font-mono text-[10px] font-semibold tracking-wider transition-colors',
        isSelected
          ? 'bg-white text-black'
          : 'text-white/60 border border-white/20 hover:border-white/40'
      )}
    >
      {label}
    </button>
  )
}
