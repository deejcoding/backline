'use client'

import { useState } from 'react'
import { useParams } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, MapPin, Calendar, Clock, Ticket, X } from 'lucide-react'
import { useAuthStore } from '@/lib/stores/authStore'
import { useShowFlyer } from '@/lib/hooks/useGigs'
import { useUser } from '@/lib/hooks/useUsers'
import { Avatar, Button } from '@/components/ui'
import { timeAgo, toDate } from '@/lib/types'
import { format } from 'date-fns'

export default function ShowFlyerDetailPage() {
  const { id } = useParams<{ id: string }>()
  const { isBlocked } = useAuthStore()

  const { data: flyer, isLoading } = useShowFlyer(id)
  const { data: poster } = useUser(flyer?.posterUID || '')

  const [showFullscreen, setShowFullscreen] = useState(false)

  if (isLoading) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-12 flex items-center justify-center">
        <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!flyer) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-12 text-center">
        <p className="text-white/50 mb-4">Show not found</p>
        <Link href="/gigs?tab=shows"><Button variant="outline">Back to Shows</Button></Link>
      </div>
    )
  }

  if (isBlocked(flyer.posterUID)) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-12 text-center">
        <p className="text-white/50 mb-4">This user is blocked</p>
        <Link href="/gigs?tab=shows"><Button variant="outline">Back to Shows</Button></Link>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-4 pb-24">
      {/* Back */}
      <Link href="/gigs?tab=shows" className="inline-flex items-center gap-1 text-sm text-white/50 hover:text-white mb-4">
        <ArrowLeft size={16} /> Back
      </Link>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Flyer Image */}
        {flyer.imageURL && (
          <button onClick={() => setShowFullscreen(true)} className="w-full">
            <img src={flyer.imageURL} alt={flyer.title} className="w-full max-h-[400px] object-contain bg-white/5" />
          </button>
        )}

        {/* Details */}
        <div>
          <h1 className="text-xl font-bold mb-3">{flyer.title}</h1>

          <div className="space-y-2 mb-4 text-sm text-white/70">
            {flyer.venue && (
              <p className="flex items-center gap-2">
                <MapPin size={14} /> {flyer.venue}
                {flyer.borough && <span className="text-white/40">({flyer.borough})</span>}
              </p>
            )}
            {flyer.eventDate && (
              <>
                <p className="flex items-center gap-2">
                  <Calendar size={14} /> {format(toDate(flyer.eventDate), 'EEEE, MMMM d, yyyy')}
                </p>
                <p className="flex items-center gap-2">
                  <Clock size={14} /> {format(toDate(flyer.eventDate), 'h:mm a')}
                </p>
              </>
            )}
          </div>

          {flyer.description && (
            <p className="text-sm text-white/80 whitespace-pre-wrap mb-4">{flyer.description}</p>
          )}

          {flyer.ticketURL && (
            <a
              href={flyer.ticketURL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 px-4 py-2 bg-accent text-black font-mono text-sm font-semibold hover:opacity-90"
            >
              <Ticket size={14} /> Get Tickets
            </a>
          )}

          <p className="font-mono text-[10px] text-white/40 mt-4">Posted {timeAgo(flyer.createdAt)}</p>
        </div>
      </div>

      {/* Poster */}
      <div className="flex items-center gap-3 p-3 border border-white/10 mt-4">
        <Link href={`/u/${flyer.posterUsername}`}>
          <Avatar src={poster?.profilePhotoURL} size="md" />
        </Link>
        <div>
          <p className="text-xs text-white/50">Posted by</p>
          <Link href={`/u/${flyer.posterUsername}`} className="font-mono text-sm hover:text-accent">
            @{flyer.posterUsername}
          </Link>
        </div>
      </div>

      {/* Fullscreen */}
      {showFullscreen && flyer.imageURL && (
        <div className="fixed inset-0 z-50 bg-black/95 flex items-center justify-center" onClick={() => setShowFullscreen(false)}>
          <button onClick={() => setShowFullscreen(false)} className="absolute top-4 right-4 text-white hover:text-accent">
            <X size={24} />
          </button>
          <img src={flyer.imageURL} alt={flyer.title} className="max-w-full max-h-full object-contain" />
        </div>
      )}
    </div>
  )
}
