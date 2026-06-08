'use client'

import { useParams } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, MapPin, Clock, DollarSign } from 'lucide-react'
import { useAuthStore } from '@/lib/stores/authStore'
import { useIsoPost } from '@/lib/hooks/useGigs'
import { useUser } from '@/lib/hooks/useUsers'
import { Avatar, Button } from '@/components/ui'
import { timeAgo, toDate } from '@/lib/types'
import { format } from 'date-fns'

function formatTimeframe(timeframe: any): string {
  if (!timeframe) return ''
  if (typeof timeframe === 'string') return timeframe
  if (timeframe?.seconds || timeframe?.toDate) return format(toDate(timeframe), 'MMM d, yyyy')
  return String(timeframe)
}

export default function ISOPostDetailPage() {
  const { id } = useParams<{ id: string }>()
  const { isBlocked } = useAuthStore()

  const { data: post, isLoading } = useIsoPost(id)
  const { data: poster } = useUser(post?.posterUID || '')

  if (isLoading) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-12 flex items-center justify-center">
        <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!post) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-12 text-center">
        <p className="text-white/50 mb-4">Post not found</p>
        <Link href="/gigs"><Button variant="outline">Back to Gigs</Button></Link>
      </div>
    )
  }

  if (isBlocked(post.posterUID)) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-12 text-center">
        <p className="text-white/50 mb-4">This user is blocked</p>
        <Link href="/gigs"><Button variant="outline">Back to Gigs</Button></Link>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-4 pb-24">
      {/* Back */}
      <Link href="/gigs" className="inline-flex items-center gap-1 text-sm text-white/50 hover:text-white mb-4">
        <ArrowLeft size={16} /> Back
      </Link>

      {/* Content */}
      <div className="border border-white/10 p-4 mb-4">
        <div className="flex gap-2 mb-3">
          <span className="px-2 py-0.5 bg-accent/20 text-accent font-mono text-[10px] font-bold">{post.roleNeeded}</span>
          {post.genre && <span className="px-2 py-0.5 bg-white/10 font-mono text-[10px]">{post.genre}</span>}
        </div>

        <p className="text-sm text-white/90 whitespace-pre-wrap mb-4">{post.description}</p>

        <div className="flex flex-wrap gap-4 text-xs text-white/50 mb-3">
          {post.location && (
            <span className="flex items-center gap-1"><MapPin size={12} /> {post.location}</span>
          )}
          {post.timeframe && (
            <span className="flex items-center gap-1"><Clock size={12} /> {formatTimeframe(post.timeframe)}</span>
          )}
          {post.budget && (
            <span className="flex items-center gap-1 text-signal-green">
              <DollarSign size={12} />
              {typeof post.budget === 'number' ? `$${post.budget}` : post.budget}
            </span>
          )}
        </div>

        <p className="font-mono text-[10px] text-white/40">Posted {timeAgo(post.createdAt)}</p>
      </div>

      {/* Poster */}
      <div className="flex items-center gap-3 p-3 border border-white/10">
        <Link href={`/u/${post.posterUsername}`}>
          <Avatar src={poster?.profilePhotoURL} size="md" />
        </Link>
        <div>
          <p className="text-xs text-white/50">Posted by</p>
          <Link href={`/u/${post.posterUsername}`} className="font-mono text-sm hover:text-accent">
            @{post.posterUsername}
          </Link>
          {poster?.roles?.[0] && (
            <p className="font-mono text-[10px] text-accent">{poster.roles[0]}</p>
          )}
        </div>
      </div>
    </div>
  )
}
