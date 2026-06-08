'use client'

import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { MapPin, Instagram, ExternalLink, LogOut } from 'lucide-react'
import { useAuthStore } from '@/lib/stores/authStore'
import { useUserListings } from '@/lib/hooks/useListings'
import { useConnections } from '@/lib/hooks/useConnections'
import { Avatar, Button } from '@/components/ui'
import { formatPrice } from '@/lib/types'

export default function ProfilePage() {
  const router = useRouter()
  const { user, profile, isGuestMode, signOut } = useAuthStore()
  const isAuthenticated = !!user && !isGuestMode

  const { data: userListings } = useUserListings(user?.uid || '')
  const { connections } = useConnections(user?.uid)

  if (!isAuthenticated) {
    return (
      <div className="max-w-6xl mx-auto px-4 py-12 text-center">
        <div className="w-16 h-16 rounded-full bg-white/5 flex items-center justify-center mx-auto mb-4">
          <span className="text-2xl text-white/30">👤</span>
        </div>
        <h2 className="font-semibold mb-2">Sign in to view your profile</h2>
        <p className="text-sm text-white/60 mb-4">
          Create an account to connect with musicians and post listings.
        </p>
        <Link href="/login">
          <Button>Sign In / Sign Up</Button>
        </Link>
      </div>
    )
  }

  const handleSignOut = async () => {
    await signOut()
    router.push('/')
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-6 pb-24">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Left - Profile Info */}
        <div className="md:col-span-1">
          <div className="sticky top-4">
            {/* Photo & Basic Info */}
            <div className="text-center mb-4">
              <div className="w-24 h-24 mx-auto bg-white/5 overflow-hidden mb-3">
                {profile?.profilePhotoURL ? (
                  <img src={profile.profilePhotoURL} alt="" className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-3xl text-white/20">
                    👤
                  </div>
                )}
              </div>
              {profile?.displayName && (
                <h1 className="text-lg font-bold">{profile.displayName}</h1>
              )}
              <p className="font-mono text-sm text-white/60">@{profile?.username}</p>
            </div>

            {/* Stats */}
            <div className="flex justify-center gap-6 mb-4 text-center">
              <div>
                <p className="font-mono text-lg font-bold text-signal-green">{connections?.length || 0}</p>
                <p className="text-[10px] text-white/50">Connected</p>
              </div>
              <div>
                <p className="font-mono text-lg font-bold text-signal-yellow">{userListings?.length || 0}</p>
                <p className="text-[10px] text-white/50">Listings</p>
              </div>
            </div>

            {/* Meta */}
            <div className="space-y-2 text-sm text-white/60 mb-4">
              {profile?.neighborhood && (
                <p className="flex items-center justify-center gap-1">
                  <MapPin size={12} /> {profile.neighborhood}
                </p>
              )}
              {profile?.instagramHandle && (
                <a
                  href={`https://instagram.com/${profile.instagramHandle}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-center gap-1 hover:text-white"
                >
                  <Instagram size={12} /> @{profile.instagramHandle}
                </a>
              )}
            </div>

            {/* Roles & Genres */}
            {profile?.roles && profile.roles.length > 0 && (
              <div className="flex flex-wrap justify-center gap-1 mb-2">
                {profile.roles.map((role) => (
                  <span key={role} className="px-2 py-0.5 font-mono text-[10px] text-signal-yellow border border-signal-yellow/30">
                    {role}
                  </span>
                ))}
              </div>
            )}
            {profile?.genres && profile.genres.length > 0 && (
              <div className="flex flex-wrap justify-center gap-1 mb-4">
                {profile.genres.map((genre) => (
                  <span key={genre} className="px-2 py-0.5 font-mono text-[10px] text-accent border border-accent/30">
                    #{genre}
                  </span>
                ))}
              </div>
            )}

            {/* Bio */}
            {profile?.bio && (
              <p className="text-sm text-white/70 text-center mb-4">{profile.bio}</p>
            )}

            {/* Sign Out */}
            <button
              onClick={handleSignOut}
              className="w-full flex items-center justify-center gap-2 py-2 text-signal-red text-sm hover:bg-white/5 transition-colors"
            >
              <LogOut size={14} /> Sign Out
            </button>
          </div>
        </div>

        {/* Right - Content */}
        <div className="md:col-span-2 space-y-6">
          {/* Portfolio */}
          {profile?.musicProjects && profile.musicProjects.length > 0 && (
            <section>
              <h2 className="font-semibold text-sm mb-3">Portfolio</h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {profile.musicProjects.map((project) => (
                  <a
                    key={project.id}
                    href={project.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-3 p-3 border border-white/10 hover:border-white/20 transition-colors"
                  >
                    {project.thumbnailURL ? (
                      <img src={project.thumbnailURL} alt="" className="w-10 h-10 object-cover" />
                    ) : (
                      <div className="w-10 h-10 bg-white/5 flex items-center justify-center text-white/30">🎵</div>
                    )}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate">{project.title}</p>
                      <p className="font-mono text-[10px] text-white/50 capitalize">{project.platform}</p>
                    </div>
                    <ExternalLink size={12} className="text-white/30" />
                  </a>
                ))}
              </div>
            </section>
          )}

          {/* Listings */}
          {userListings && userListings.length > 0 && (
            <section>
              <h2 className="font-semibold text-sm mb-3">Your Listings</h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                {userListings.map((listing) => (
                  <Link key={listing.id} href={`/market/${listing.id}`} className="group">
                    <div className="aspect-square bg-white/5 overflow-hidden mb-2">
                      {listing.photoURLs?.[0] ? (
                        <img
                          src={listing.photoURLs[0]}
                          alt=""
                          className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-white/20">🎸</div>
                      )}
                    </div>
                    <p className="text-sm font-medium truncate">{listing.title}</p>
                    {listing.price && (
                      <p className="font-mono text-sm font-bold text-signal-green">
                        {formatPrice(listing.price)}
                      </p>
                    )}
                  </Link>
                ))}
              </div>
            </section>
          )}

          {/* Empty state */}
          {(!userListings || userListings.length === 0) && (!profile?.musicProjects || profile.musicProjects.length === 0) && (
            <div className="text-center py-12 text-white/40">
              <p className="text-sm">No listings or portfolio items yet</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
