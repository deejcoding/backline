'use client'

import Link from 'next/link'
import { ChevronRight } from 'lucide-react'
import { useIsoPosts, useShowFlyers } from '@/lib/hooks/useGigs'
import { useListings } from '@/lib/hooks/useListings'
import { useUsers } from '@/lib/hooks/useUsers'
import { useAuthStore } from '@/lib/stores/authStore'
import { Avatar } from '@/components/ui'
import { timeAgo, toDate, formatPrice } from '@/lib/types'
import { format } from 'date-fns'

export default function HomePage() {
  const { user, profile, isGuestMode } = useAuthStore()
  const isAuthenticated = !!user && !isGuestMode

  const { data: isoPosts, isLoading: isoLoading } = useIsoPosts()
  const { data: showFlyers, isLoading: flyersLoading } = useShowFlyers()
  const { data: users, isLoading: usersLoading } = useUsers()
  const { data: listings, isLoading: listingsLoading } = useListings()

  const artists = users?.filter((u) => u.roles?.length > 0 || u.genres?.length > 0) || []

  const matchingPosts = isAuthenticated && profile?.roles?.length
    ? isoPosts?.filter((post) => {
        const postRole = post.roleNeeded?.toLowerCase() || ''
        return profile.roles.some((role) => {
          const r = role.toLowerCase()
          return r.includes(postRole) || postRole.includes(r)
        })
      })
    : isoPosts

  const isLoading = isoLoading || flyersLoading || usersLoading || listingsLoading

  return (
    <div className="max-w-6xl mx-auto px-4 py-6 pb-24">
      {/* Greeting */}
      <div className="mb-6">
        {isAuthenticated ? (
          <>
            <h1 className="text-xl font-semibold">
              Welcome back, <span className="font-bold">{profile?.username}</span>
            </h1>
            {matchingPosts && matchingPosts.length > 0 && (
              <p className="text-sm text-white/60 mt-1">
                <span className="text-signal-green font-semibold">{matchingPosts.length} gigs</span> match your skills
              </p>
            )}
          </>
        ) : (
          <>
            <h1 className="text-xl font-bold">Welcome to Backline</h1>
            <p className="text-sm text-white/60 mt-1">NYC's music community</p>
          </>
        )}
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Left column - Gigs */}
          <div className="lg:col-span-2 space-y-6">
            {/* Open Roles */}
            {matchingPosts && matchingPosts.length > 0 && (
              <section>
                <SectionHeader label="Open Roles" href="/gigs" />
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {matchingPosts.slice(0, 4).map((post) => (
                    <Link
                      key={post.id}
                      href={`/gigs/iso/${post.id}`}
                      className="p-3 border border-white/10 hover:border-white/20 transition-colors"
                    >
                      <div className="flex items-center justify-between mb-2">
                        <span className="font-mono text-xs font-bold text-accent">
                          {post.roleNeeded}
                        </span>
                        <span className="font-mono text-[10px] text-white/40">
                          {timeAgo(post.createdAt)}
                        </span>
                      </div>
                      <p className="text-sm text-white/70 line-clamp-2 mb-2">
                        {post.description}
                      </p>
                      <div className="flex items-center gap-2 text-xs">
                        {post.budget && (
                          <span className="font-mono text-signal-green font-semibold">
                            {typeof post.budget === 'number' ? `$${post.budget}` : post.budget}
                          </span>
                        )}
                        {post.genre && (
                          <span className="text-white/40">{post.genre}</span>
                        )}
                        <span className="text-white/30 ml-auto">@{post.posterUsername}</span>
                      </div>
                    </Link>
                  ))}
                </div>
              </section>
            )}

            {/* Recent Listings */}
            {listings && listings.length > 0 && (
              <section>
                <SectionHeader label="Gear for Sale" href="/market" />
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
                  {listings.slice(0, 8).map((listing) => (
                    <Link key={listing.id} href={`/market/${listing.id}`} className="group">
                      <div className="aspect-square bg-white/5 overflow-hidden mb-2">
                        {listing.photoURLs?.[0] ? (
                          <img
                            src={listing.photoURLs[0]}
                            alt=""
                            className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-white/20">
                            🎸
                          </div>
                        )}
                      </div>
                      <p className="text-sm font-medium truncate">{listing.title}</p>
                      <div className="flex items-center gap-2">
                        {listing.price && (
                          <span className="font-mono text-xs font-bold text-signal-green">
                            {formatPrice(listing.price)}
                          </span>
                        )}
                        <span className="font-mono text-[10px] text-white/40">
                          {listing.condition}
                        </span>
                      </div>
                    </Link>
                  ))}
                </div>
              </section>
            )}
          </div>

          {/* Right column - Shows & Artists */}
          <div className="space-y-6">
            {/* Upcoming Shows */}
            {showFlyers && showFlyers.length > 0 && (
              <section>
                <SectionHeader label="Upcoming Shows" href="/gigs?tab=shows" />
                <div className="space-y-2">
                  {showFlyers.slice(0, 5).map((flyer) => (
                    <Link
                      key={flyer.id}
                      href={`/gigs/show/${flyer.id}`}
                      className="flex gap-3 p-2 border border-white/10 hover:border-white/20 transition-colors"
                    >
                      <div className="w-12 h-12 bg-white/5 flex-shrink-0 overflow-hidden">
                        {flyer.imageURL ? (
                          <img src={flyer.imageURL} alt="" className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-white/20 text-xs">
                            📅
                          </div>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium truncate">{flyer.title}</p>
                        <p className="font-mono text-[10px] text-white/50 truncate">
                          {flyer.venue}
                        </p>
                        {flyer.eventDate && (
                          <p className="font-mono text-[10px] font-bold text-signal-yellow">
                            {format(toDate(flyer.eventDate), 'MMM d')}
                          </p>
                        )}
                      </div>
                    </Link>
                  ))}
                </div>
              </section>
            )}

            {/* Artists */}
            {artists.length > 0 && (
              <section>
                <SectionHeader label="Artists" href="/gigs?tab=services" />
                <div className="grid grid-cols-3 gap-2">
                  {artists.slice(0, 9).map((artist) => (
                    <Link
                      key={artist.id}
                      href={`/u/${artist.username}`}
                      className="text-center group"
                    >
                      <div className="w-full aspect-square bg-white/5 overflow-hidden mb-1">
                        {artist.profilePhotoURL ? (
                          <img
                            src={artist.profilePhotoURL}
                            alt=""
                            className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-white/20">
                            👤
                          </div>
                        )}
                      </div>
                      <p className="text-xs font-medium truncate">{artist.username}</p>
                      {artist.roles?.[0] && (
                        <p className="font-mono text-[9px] text-accent truncate">{artist.roles[0]}</p>
                      )}
                    </Link>
                  ))}
                </div>
              </section>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

function SectionHeader({ label, href }: { label: string; href: string }) {
  return (
    <div className="flex items-center justify-between mb-3">
      <h2 className="font-semibold text-sm">{label}</h2>
      <Link href={href} className="flex items-center gap-1 text-xs text-white/40 hover:text-white/60">
        See all <ChevronRight size={12} />
      </Link>
    </div>
  )
}
