'use client'

import Link from 'next/link'
import { MapPin, Clock, DollarSign } from 'lucide-react'
import { Card, Badge } from '@/components/ui'
import { timeAgo, toDate } from '@/lib/types'
import type { ISOPost } from '@/lib/types'
import { format } from 'date-fns'

interface ISOPostCardProps {
  post: ISOPost
}

// Helper to safely render timeframe
function formatTimeframe(timeframe: any): string {
  if (!timeframe) return ''
  if (typeof timeframe === 'string') return timeframe
  // If it's a Timestamp object, convert and format
  if (timeframe?.seconds || timeframe?.toDate) {
    return format(toDate(timeframe), 'MMM d')
  }
  return String(timeframe)
}

export function ISOPostCard({ post }: ISOPostCardProps) {
  const timeframeStr = formatTimeframe(post.timeframe)

  return (
    <Link href={`/gigs/iso/${post.id}`}>
      <Card variant="interactive" className="p-4">
        {/* Header */}
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <Badge variant="accent">{post.roleNeeded}</Badge>
            {post.genre && <Badge>{post.genre}</Badge>}
          </div>
          <span className="font-mono text-[10px] text-muted">{timeAgo(post.createdAt)}</span>
        </div>

        {/* Description */}
        <p className="font-mono text-xs text-muted line-clamp-3 mb-3">
          {post.description}
        </p>

        {/* Meta */}
        <div className="flex flex-wrap gap-3 text-[10px] font-mono text-muted">
          {post.location && (
            <span className="flex items-center gap-1">
              <MapPin size={10} />
              {post.location}
            </span>
          )}
          {timeframeStr && (
            <span className="flex items-center gap-1">
              <Clock size={10} />
              {timeframeStr}
            </span>
          )}
          {post.budget && (
            <span className="flex items-center gap-1 text-signal-green">
              <DollarSign size={10} />
              {typeof post.budget === 'number' ? `$${post.budget}` : post.budget}
            </span>
          )}
        </div>

        {/* Poster */}
        <div className="mt-3 pt-3 border-t border-dim flex items-center gap-2">
          <span className="font-mono text-xs text-muted">Posted by</span>
          <Link
            href={`/u/${post.posterUsername}`}
            className="font-mono text-xs text-ink hover:text-accent transition-colors"
            onClick={(e) => e.stopPropagation()}
          >
            @{post.posterUsername}
          </Link>
        </div>
      </Card>
    </Link>
  )
}
