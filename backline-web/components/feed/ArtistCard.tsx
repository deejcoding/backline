'use client'

import Link from 'next/link'
import { MapPin } from 'lucide-react'
import { Card, Avatar, Badge } from '@/components/ui'
import type { UserProfile } from '@/lib/types'

interface ArtistCardProps {
  user: UserProfile
}

export function ArtistCard({ user }: ArtistCardProps) {
  return (
    <Link href={`/u/${user.username}`}>
      <Card variant="interactive" className="p-4">
        {/* Header */}
        <div className="flex items-start gap-3">
          <Avatar src={user.profilePhotoURL} size="lg" />
          <div className="flex-1 min-w-0">
            <h3 className="font-sans text-sm font-semibold text-ink truncate">
              {user.displayName || user.username}
            </h3>
            <p className="font-mono text-xs text-muted">@{user.username}</p>
            {user.neighborhood && (
              <p className="flex items-center gap-1 font-mono text-[10px] text-muted mt-1">
                <MapPin size={10} />
                {user.neighborhood}
              </p>
            )}
          </div>
        </div>

        {/* Roles */}
        {user.roles.length > 0 && (
          <div className="mt-3 flex flex-wrap gap-1">
            {user.roles.slice(0, 3).map((role) => (
              <Badge key={role} variant="accent">
                {role}
              </Badge>
            ))}
            {user.roles.length > 3 && (
              <Badge>+{user.roles.length - 3}</Badge>
            )}
          </div>
        )}

        {/* Genres */}
        {user.genres.length > 0 && (
          <div className="mt-2 flex flex-wrap gap-1">
            {user.genres.slice(0, 3).map((genre) => (
              <span
                key={genre}
                className="font-mono text-[9px] text-muted uppercase tracking-wider"
              >
                {genre}
              </span>
            ))}
            {user.genres.length > 3 && (
              <span className="font-mono text-[9px] text-muted">
                +{user.genres.length - 3}
              </span>
            )}
          </div>
        )}

        {/* Bio preview */}
        {user.bio && (
          <p className="mt-3 font-mono text-xs text-muted line-clamp-2">
            {user.bio}
          </p>
        )}
      </Card>
    </Link>
  )
}
