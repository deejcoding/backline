'use client'

import Link from 'next/link'
import { MapPin, Calendar, Ticket } from 'lucide-react'
import { Card } from '@/components/ui'
import { timeAgo, toDate } from '@/lib/types'
import type { ShowFlyer } from '@/lib/types'
import { format } from 'date-fns'

interface ShowFlyerCardProps {
  flyer: ShowFlyer
}

export function ShowFlyerCard({ flyer }: ShowFlyerCardProps) {
  return (
    <Link href={`/gigs/show/${flyer.id}`}>
      <Card variant="interactive" className="p-0 overflow-hidden group">
        {/* Image */}
        {flyer.imageURL ? (
          <div className="relative aspect-[3/4] bg-dim">
            <img
              src={flyer.imageURL}
              alt={flyer.title}
              className="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
            />
          </div>
        ) : (
          <div className="aspect-[3/4] bg-soft flex items-center justify-center">
            <Calendar size={48} className="text-dim" />
          </div>
        )}

        {/* Content */}
        <div className="p-3">
          {/* Title */}
          <h3 className="font-sans text-sm font-semibold text-ink line-clamp-1 mb-2">
            {flyer.title}
          </h3>

          {/* Meta */}
          <div className="flex flex-col gap-1 text-[10px] font-mono text-muted">
            {flyer.venue && (
              <span className="flex items-center gap-1">
                <MapPin size={10} />
                {flyer.venue}
              </span>
            )}
            {flyer.eventDate && (
              <span className="flex items-center gap-1">
                <Calendar size={10} />
                {format(toDate(flyer.eventDate), 'EEE, MMM d')}
              </span>
            )}
            {flyer.ticketURL && (
              <a
                href={flyer.ticketURL}
                target="_blank"
                rel="noopener noreferrer"
                onClick={(e) => e.stopPropagation()}
                className="flex items-center gap-1 text-accent hover:underline"
              >
                <Ticket size={10} />
                Get Tickets
              </a>
            )}
          </div>

          {/* Poster */}
          <div className="mt-2 pt-2 border-t border-dim flex items-center justify-between">
            <Link
              href={`/u/${flyer.posterUsername}`}
              className="font-mono text-[10px] text-muted hover:text-accent transition-colors"
              onClick={(e) => e.stopPropagation()}
            >
              @{flyer.posterUsername}
            </Link>
            <span className="font-mono text-[10px] text-muted">{timeAgo(flyer.createdAt)}</span>
          </div>
        </div>
      </Card>
    </Link>
  )
}
