'use client'

import { useParams } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, MapPin, DollarSign, ExternalLink } from 'lucide-react'
import { useAuthStore } from '@/lib/stores/authStore'
import { useServiceListing } from '@/lib/hooks/useGigs'
import { useUser } from '@/lib/hooks/useUsers'
import { Avatar, Button } from '@/components/ui'
import { timeAgo } from '@/lib/types'

export default function ServiceDetailPage() {
  const { id } = useParams<{ id: string }>()
  const { isBlocked } = useAuthStore()

  const { data: service, isLoading } = useServiceListing(id)
  const { data: seller } = useUser(service?.sellerUID || '')

  if (isLoading) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-12 flex items-center justify-center">
        <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!service) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-12 text-center">
        <p className="text-white/50 mb-4">Service not found</p>
        <Link href="/gigs?tab=services"><Button variant="outline">Back to Services</Button></Link>
      </div>
    )
  }

  if (isBlocked(service.sellerUID)) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-12 text-center">
        <p className="text-white/50 mb-4">This user is blocked</p>
        <Link href="/gigs?tab=services"><Button variant="outline">Back to Services</Button></Link>
      </div>
    )
  }

  const formatRate = () => {
    if (!service.rate) return 'Rate negotiable'
    const amount = typeof service.rate === 'number' ? `$${service.rate}` : service.rate
    if (service.rateType === 'hourly') return `${amount}/hr`
    if (service.rateType === 'flat') return `${amount} flat`
    return amount
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-4 pb-24">
      {/* Back */}
      <Link href="/gigs?tab=services" className="inline-flex items-center gap-1 text-sm text-white/50 hover:text-white mb-4">
        <ArrowLeft size={16} /> Back
      </Link>

      {/* Content */}
      <div className="border border-white/10 p-4 mb-4">
        <h1 className="text-xl font-bold mb-2">{service.title}</h1>

        <div className="flex items-center gap-2 mb-3">
          <span className="px-2 py-0.5 bg-accent/20 text-accent font-mono text-[10px] font-bold">{service.category}</span>
          {service.borough && (
            <span className="flex items-center gap-1 font-mono text-[10px] text-white/50">
              <MapPin size={10} /> {service.borough}
            </span>
          )}
        </div>

        <p className="text-sm text-white/90 whitespace-pre-wrap mb-4">{service.description}</p>

        <div className="flex items-center gap-1.5 text-signal-green font-mono text-sm font-bold mb-4">
          <DollarSign size={14} /> {formatRate()}
        </div>

        {service.portfolioURL && (
          <a
            href={service.portfolioURL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 font-mono text-sm text-accent hover:underline"
          >
            <ExternalLink size={14} /> View Portfolio
          </a>
        )}

        <p className="font-mono text-[10px] text-white/40 mt-4">Posted {timeAgo(service.createdAt)}</p>
      </div>

      {/* Seller */}
      <div className="flex items-center gap-3 p-3 border border-white/10">
        <Link href={`/u/${service.sellerUsername}`}>
          <Avatar src={seller?.profilePhotoURL} size="md" />
        </Link>
        <div>
          <p className="text-xs text-white/50">Offered by</p>
          <Link href={`/u/${service.sellerUsername}`} className="font-mono text-sm hover:text-accent">
            @{service.sellerUsername}
          </Link>
          {seller?.roles?.[0] && (
            <p className="font-mono text-[10px] text-accent">{seller.roles[0]}</p>
          )}
        </div>
      </div>
    </div>
  )
}
