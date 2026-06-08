'use client'

import { useParams } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, MapPin, Instagram, ExternalLink } from 'lucide-react'
import { useUserByUsername } from '@/lib/hooks/useUsers'
import { useAuthStore } from '@/lib/stores/authStore'
import { Button } from '@/components/ui'

export default function PublicProfilePage() {
  const { username } = useParams<{ username: string }>()
  const { user, isBlocked } = useAuthStore()

  const { data: profile, isLoading } = useUserByUsername(username)

  const isOwnProfile = profile && user && profile.id === user.uid

  if (isLoading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12 flex items-center justify-center">
        <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!profile) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12 text-center">
        <p className="text-white/50 mb-4">User not found</p>
        <Link href="/"><Button variant="outline">Go Home</Button></Link>
      </div>
    )
  }

  if (isBlocked(profile.id)) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12 text-center">
        <p className="text-white/50 mb-4">This user is blocked</p>
        <Link href="/"><Button variant="outline">Go Home</Button></Link>
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-4 pb-24">
      {/* Back */}
      <Link href="/" className="inline-flex items-center gap-1 text-sm text-white/50 hover:text-white mb-4">
        <ArrowLeft size={16} /> Back
      </Link>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Left - Profile Info */}
        <div className="md:col-span-1">
          {/* Photo & Basic Info */}
          <div className="text-center mb-4">
            <div className="w-24 h-24 mx-auto bg-white/5 overflow-hidden mb-3">
              {profile.profilePhotoURL ? (
                <img src={profile.profilePhotoURL} alt="" className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-3xl text-white/20">👤</div>
              )}
            </div>
            {profile.displayName && <h1 className="text-lg font-bold">{profile.displayName}</h1>}
            <p className="font-mono text-sm text-white/60">@{profile.username}</p>
          </div>

          {/* Meta */}
          <div className="space-y-2 text-sm text-white/60 mb-4">
            {profile.neighborhood && (
              <p className="flex items-center justify-center gap-1">
                <MapPin size={12} /> {profile.neighborhood}
              </p>
            )}
            {profile.instagramHandle && (
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
          {profile.roles && profile.roles.length > 0 && (
            <div className="flex flex-wrap justify-center gap-1 mb-2">
              {profile.roles.map((role) => (
                <span key={role} className="px-2 py-0.5 font-mono text-[10px] text-signal-yellow border border-signal-yellow/30">
                  {role}
                </span>
              ))}
            </div>
          )}
          {profile.genres && profile.genres.length > 0 && (
            <div className="flex flex-wrap justify-center gap-1 mb-4">
              {profile.genres.map((genre) => (
                <span key={genre} className="px-2 py-0.5 font-mono text-[10px] text-accent border border-accent/30">
                  #{genre}
                </span>
              ))}
            </div>
          )}

          {/* Bio */}
          {profile.bio && (
            <p className="text-sm text-white/70 text-center mb-4">{profile.bio}</p>
          )}

          {/* Own profile link */}
          {isOwnProfile && (
            <Link href="/profile" className="block">
              <Button variant="outline" size="sm" className="w-full">View Full Profile</Button>
            </Link>
          )}
        </div>

        {/* Right - Content */}
        <div className="md:col-span-2 space-y-6">
          {/* Portfolio */}
          {profile.musicProjects && profile.musicProjects.length > 0 && (
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

          {/* Featured */}
          {profile.featuredProjects && profile.featuredProjects.length > 0 && (
            <section>
              <h2 className="font-semibold text-sm mb-3">Featured</h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {profile.featuredProjects.map((project) => (
                  <a
                    key={project.id}
                    href={project.externalURL}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-3 p-3 border border-white/10 hover:border-white/20 transition-colors"
                  >
                    {project.albumImageURL && (
                      <img src={project.albumImageURL} alt="" className="w-10 h-10 object-cover" />
                    )}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate">{project.name}</p>
                      <p className="font-mono text-[10px] text-white/50 truncate">{project.artistName}</p>
                    </div>
                    <ExternalLink size={12} className="text-white/30" />
                  </a>
                ))}
              </div>
            </section>
          )}

          {/* Empty state */}
          {(!profile.musicProjects || profile.musicProjects.length === 0) && (!profile.featuredProjects || profile.featuredProjects.length === 0) && (
            <div className="text-center py-12 text-white/40">
              <p className="text-sm">No portfolio items yet</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
