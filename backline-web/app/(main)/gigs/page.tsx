'use client'

import { useState } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, MapPin, Clock, DollarSign, Calendar } from 'lucide-react'
import { useIsoPosts, useServiceListings, useShowFlyers } from '@/lib/hooks/useGigs'
import { useUsers } from '@/lib/hooks/useUsers'
import { useAuthStore } from '@/lib/stores/authStore'
import { Avatar } from '@/components/ui'
import { timeAgo, toDate } from '@/lib/types'
import { format } from 'date-fns'
import clsx from 'clsx'

const tabs = [
  { id: 'iso', label: 'Open Roles' },
  { id: 'artists', label: 'Artists' },
  { id: 'services', label: 'Services' },
  { id: 'shows', label: 'Shows' },
]

export default function GigsPage() {
  const searchParams = useSearchParams()
  const initialTab = searchParams.get('tab') || 'iso'
  const [activeTab, setActiveTab] = useState(initialTab)
  const [searchText, setSearchText] = useState('')

  const { isBlocked } = useAuthStore()

  const { data: isoPosts, isLoading: isoLoading } = useIsoPosts()
  const { data: artists, isLoading: artistsLoading } = useUsers()
  const { data: services, isLoading: servicesLoading } = useServiceListings()
  const { data: flyers, isLoading: flyersLoading } = useShowFlyers()

  const filteredIsoPosts = isoPosts?.filter((post) => !isBlocked(post.posterUID))
  const filteredArtists = artists?.filter((artist) => !isBlocked(artist.id))
  const filteredServices = services?.filter((service) => !isBlocked(service.sellerUID))
  const filteredFlyers = flyers?.filter((flyer) => !isBlocked(flyer.posterUID))

  const searchedIsoPosts = filteredIsoPosts?.filter((post) =>
    !searchText ||
    post.roleNeeded?.toLowerCase().includes(searchText.toLowerCase()) ||
    post.description?.toLowerCase().includes(searchText.toLowerCase())
  )

  const searchedArtists = filteredArtists?.filter((artist) =>
    !searchText ||
    artist.username?.toLowerCase().includes(searchText.toLowerCase()) ||
    artist.displayName?.toLowerCase().includes(searchText.toLowerCase()) ||
    artist.roles?.some(r => r.toLowerCase().includes(searchText.toLowerCase())) ||
    artist.genres?.some(g => g.toLowerCase().includes(searchText.toLowerCase()))
  )

  const searchedServices = filteredServices?.filter((service) =>
    !searchText ||
    service.sellerUsername?.toLowerCase().includes(searchText.toLowerCase()) ||
    service.title?.toLowerCase().includes(searchText.toLowerCase())
  )

  const searchedFlyers = filteredFlyers?.filter((flyer) =>
    !searchText ||
    flyer.title?.toLowerCase().includes(searchText.toLowerCase()) ||
    flyer.venue?.toLowerCase().includes(searchText.toLowerCase())
  )

  const isLoading =
    activeTab === 'iso' ? isoLoading :
    activeTab === 'artists' ? artistsLoading :
    activeTab === 'services' ? servicesLoading :
    flyersLoading

  return (
    <div className="max-w-6xl mx-auto px-4 py-4 pb-24">
      {/* Back */}
      <Link href="/" className="inline-flex items-center gap-1 text-sm text-white/50 hover:text-white mb-4">
        <ArrowLeft size={16} /> Home
      </Link>

      {/* Tabs */}
      <div className="flex gap-1 border-b border-white/10 mb-4 overflow-x-auto hide-scrollbar -mx-4 px-4">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={clsx(
              'px-4 py-3 font-mono text-xs tracking-wider transition-colors relative whitespace-nowrap flex-shrink-0',
              activeTab === tab.id ? 'text-white font-bold' : 'text-white/45 hover:text-white/70'
            )}
          >
            {tab.label}
            {activeTab === tab.id && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-accent" />
            )}
          </button>
        ))}
      </div>

      {/* Search */}
      <div className="mb-4">
        <input
          type="text"
          placeholder="Search..."
          value={searchText}
          onChange={(e) => setSearchText(e.target.value)}
          className="w-full max-w-md px-3 py-2 bg-white/5 border border-white/10 text-sm placeholder:text-white/30 focus:outline-none focus:border-accent"
        />
      </div>

      {/* Content */}
      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          {activeTab === 'iso' && (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {searchedIsoPosts?.map((post) => (
                <Link
                  key={post.id}
                  href={`/gigs/iso/${post.id}`}
                  className="p-3 border border-white/10 hover:border-white/20 transition-colors"
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className="px-2 py-0.5 bg-accent/20 text-accent font-mono text-[10px] font-bold">
                      {post.roleNeeded}
                    </span>
                    <span className="font-mono text-[10px] text-white/40">{timeAgo(post.createdAt)}</span>
                  </div>
                  <p className="text-sm text-white/80 line-clamp-2 mb-2">{post.description}</p>
                  <div className="flex flex-wrap gap-3 text-[10px] text-white/50">
                    {post.location && (
                      <span className="flex items-center gap-1">
                        <MapPin size={10} /> {post.location}
                      </span>
                    )}
                    {post.budget && (
                      <span className="flex items-center gap-1 text-signal-green font-semibold">
                        <DollarSign size={10} />
                        {typeof post.budget === 'number' ? `$${post.budget}` : post.budget}
                      </span>
                    )}
                  </div>
                  <p className="font-mono text-[10px] text-white/30 mt-2">@{post.posterUsername}</p>
                </Link>
              ))}
              {searchedIsoPosts?.length === 0 && (
                <p className="col-span-full text-center py-8 text-sm text-white/40">
                  {searchText ? 'No posts found' : 'No open roles yet'}
                </p>
              )}
            </div>
          )}

          {activeTab === 'artists' && (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
              {searchedArtists?.map((artist) => (
                <Link
                  key={artist.id}
                  href={`/u/${artist.username}`}
                  className="p-3 border border-white/10 hover:border-white/20 transition-colors text-center"
                >
                  <div className="w-16 h-16 mx-auto mb-2 bg-white/5 overflow-hidden rounded-full border border-white/10">
                    {artist.profilePhotoURL ? (
                      <img src={artist.profilePhotoURL} alt="" className="w-full h-full object-cover" loading="lazy" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-white/20 text-2xl">👤</div>
                    )}
                  </div>
                  <p className="text-sm font-medium truncate">{artist.displayName || artist.username}</p>
                  <p className="font-mono text-[10px] text-white/50 truncate">@{artist.username}</p>
                  {artist.roles && artist.roles.length > 0 && (
                    <p className="font-mono text-[10px] text-accent truncate mt-1">{artist.roles[0]}</p>
                  )}
                  {artist.neighborhood && (
                    <p className="font-mono text-[10px] text-white/40 truncate flex items-center justify-center gap-1 mt-1">
                      <MapPin size={8} /> {artist.neighborhood}
                    </p>
                  )}
                </Link>
              ))}
              {searchedArtists?.length === 0 && (
                <p className="col-span-full text-center py-8 text-sm text-white/40">
                  {searchText ? 'No artists found' : 'No artists yet'}
                </p>
              )}
            </div>
          )}

          {activeTab === 'services' && (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
              {searchedServices?.map((service) => (
                <Link
                  key={service.id}
                  href={`/gigs/service/${service.id}`}
                  className="p-3 border border-white/10 hover:border-white/20 transition-colors text-center"
                >
                  <Avatar size="lg" className="mx-auto mb-2" />
                  <p className="text-sm font-medium truncate">{service.sellerUsername}</p>
                  <p className="font-mono text-[10px] text-accent truncate">{service.title}</p>
                  {service.rate && (
                    <p className="font-mono text-xs text-signal-green font-semibold mt-1">
                      {typeof service.rate === 'number' ? `$${service.rate}` : service.rate}
                    </p>
                  )}
                </Link>
              ))}
              {searchedServices?.length === 0 && (
                <p className="col-span-full text-center py-8 text-sm text-white/40">
                  {searchText ? 'No services found' : 'No services yet'}
                </p>
              )}
            </div>
          )}

          {activeTab === 'shows' && (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
              {searchedFlyers?.map((flyer) => (
                <Link
                  key={flyer.id}
                  href={`/gigs/show/${flyer.id}`}
                  className="group"
                >
                  <div className="aspect-[3/4] bg-white/5 overflow-hidden mb-2">
                    {flyer.imageURL ? (
                      <img
                        src={flyer.imageURL}
                        alt=""
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                        loading="lazy"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-white/20">
                        📅
                      </div>
                    )}
                  </div>
                  <p className="text-sm font-medium line-clamp-1">{flyer.title}</p>
                  {flyer.venue && (
                    <p className="font-mono text-[10px] text-white/50 truncate">{flyer.venue}</p>
                  )}
                  {flyer.eventDate && (
                    <p className="font-mono text-[10px] font-bold text-signal-yellow">
                      {format(toDate(flyer.eventDate), 'MMM d')}
                    </p>
                  )}
                </Link>
              ))}
              {searchedFlyers?.length === 0 && (
                <p className="col-span-full text-center py-8 text-sm text-white/40">
                  {searchText ? 'No shows found' : 'No shows yet'}
                </p>
              )}
            </div>
          )}
        </>
      )}
    </div>
  )
}
