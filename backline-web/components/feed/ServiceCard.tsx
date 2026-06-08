'use client'

import Link from 'next/link'
import { Avatar } from '@/components/ui'
import type { ServiceListing, UserProfile } from '@/lib/types'

interface ServiceCardProps {
  service: ServiceListing | UserProfile
}

export function ServiceCard({ service }: ServiceCardProps) {
  // Handle both ServiceListing and UserProfile types
  const username = 'username' in service ? service.username : service.sellerUsername
  const profilePhotoURL = 'profilePhotoURL' in service ? service.profilePhotoURL : undefined
  const title = 'title' in service ? service.title : service.roles?.join(', ') || 'Artist'
  const rate = 'rate' in service ? service.rate : undefined
  const linkHref = 'uid' in service ? `/u/${username}` : `/gigs/service/${service.id}`

  return (
    <Link href={linkHref} className="block">
      <div className="flex items-start gap-3 p-3 border border-white/10 hover:border-white/20 transition-colors">
        {/* Profile photo */}
        <Avatar src={profilePhotoURL} size="md" />

        {/* Info */}
        <div className="flex-1 min-w-0">
          <h3 className="font-bold text-sm line-clamp-2">
            {title}
          </h3>

          {rate && (
            <p className="font-mono text-xs font-bold text-signal-green mt-1">
              {typeof rate === 'number' ? `$${rate}` : rate}
            </p>
          )}

          <p className="font-mono text-[10px] text-white/50 mt-1 truncate">
            @{username}
          </p>
        </div>
      </div>
    </Link>
  )
}
