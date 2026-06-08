'use client'

import { useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, Calendar, DollarSign, MapPin, Music, FileText, Image as ImageIcon } from 'lucide-react'
import { useAuthStore } from '@/lib/stores/authStore'
import { useCreateISOPost, useCreateServiceListing, useCreateShowFlyer } from '@/lib/hooks/useGigs'
import { Button, Input, Textarea, Select, Card, Badge } from '@/components/ui'
import { PhotoUploader } from '@/components/listings'
import clsx from 'clsx'

const ISO_ROLES = [
  'Drums', 'Guitar', 'Bass', 'Vocals', 'Keys', 'Synth',
  'DJ', 'Producer', 'Recording Engineer', 'Mixing Engineer',
  'Live Sound', 'Photography', 'Videography', 'Graphic Design',
  'Booking', 'Management', 'Saxophone', 'Trumpet', 'Violin',
]

const GENRES = [
  'Rock', 'Indie', 'Punk', 'Metal', 'Jazz', 'Hip-Hop',
  'Electronic', 'House', 'Techno', 'Ambient', 'Folk',
  'Country', 'R&B', 'Soul', 'Funk', 'Pop', 'Classical',
  'Experimental', 'Noise', 'Shoegaze', 'Post-Punk',
]

const BOROUGHS = [
  'Manhattan', 'Brooklyn', 'Queens', 'Bronx', 'Staten Island',
]

const TIMEFRAMES = [
  { value: 'asap', label: 'ASAP' },
  { value: 'thisWeek', label: 'This Week' },
  { value: 'thisMonth', label: 'This Month' },
  { value: 'flexible', label: 'Flexible' },
]

const SERVICE_CATEGORIES = [
  'Recording', 'Mixing', 'Mastering', 'Production',
  'Live Sound', 'Photography', 'Videography',
  'Graphic Design', 'Booking', 'Management',
  'Lessons', 'Session Work', 'Other',
]

type TabType = 'iso' | 'service' | 'flyer'

export default function CreateGigPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const initialTab = (searchParams.get('type') as TabType) || 'iso'

  const { user, profile, isGuestMode } = useAuthStore()
  const isAuthenticated = !!user && !isGuestMode

  const createISOPost = useCreateISOPost()
  const createServiceListing = useCreateServiceListing()
  const createShowFlyer = useCreateShowFlyer()

  const [activeTab, setActiveTab] = useState<TabType>(initialTab)
  const [isSubmitting, setIsSubmitting] = useState(false)

  // ISO Post state
  const [isoRole, setIsoRole] = useState('')
  const [isoGenre, setIsoGenre] = useState('')
  const [isoDescription, setIsoDescription] = useState('')
  const [isoBudget, setIsoBudget] = useState('')
  const [isoTimeframe, setIsoTimeframe] = useState('flexible')
  const [isoBorough, setIsoBorough] = useState('')

  // Service Listing state
  const [serviceTitle, setServiceTitle] = useState('')
  const [serviceCategory, setServiceCategory] = useState('')
  const [serviceDescription, setServiceDescription] = useState('')
  const [serviceRate, setServiceRate] = useState('')
  const [serviceRateType, setServiceRateType] = useState<'hourly' | 'flat' | 'negotiable'>('hourly')
  const [servicePortfolioUrl, setServicePortfolioUrl] = useState('')
  const [serviceBorough, setServiceBorough] = useState('')

  // Show Flyer state
  const [flyerTitle, setFlyerTitle] = useState('')
  const [flyerVenue, setFlyerVenue] = useState('')
  const [flyerDate, setFlyerDate] = useState('')
  const [flyerTime, setFlyerTime] = useState('')
  const [flyerDescription, setFlyerDescription] = useState('')
  const [flyerTicketUrl, setFlyerTicketUrl] = useState('')
  const [flyerPhotos, setFlyerPhotos] = useState<File[]>([])
  const [flyerBorough, setFlyerBorough] = useState('')

  if (!isAuthenticated) {
    return (
      <div className="max-w-[1280px] mx-auto px-4 md:px-8 py-12 text-center">
        <p className="font-mono text-muted mb-4">Please sign in to create a post</p>
        <Link href="/login">
          <Button>Sign In</Button>
        </Link>
      </div>
    )
  }

  const handleCreateISO = async () => {
    if (!isoRole || !isoDescription) return
    if (!user || !profile) return

    setIsSubmitting(true)
    try {
      await createISOPost.mutateAsync({
        authorUID: user.uid,
        authorUsername: profile.username || '',
        role: isoRole,
        genre: isoGenre || undefined,
        description: isoDescription,
        budget: isoBudget ? parseInt(isoBudget) : undefined,
        timeframe: isoTimeframe as any,
        borough: isoBorough || undefined,
      })
      router.push('/gigs')
    } catch (error) {
      console.error('Error creating ISO post:', error)
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleCreateService = async () => {
    if (!serviceTitle || !serviceCategory || !serviceDescription) return
    if (!user || !profile) return

    setIsSubmitting(true)
    try {
      await createServiceListing.mutateAsync({
        authorUID: user.uid,
        authorUsername: profile.username || '',
        title: serviceTitle,
        category: serviceCategory,
        description: serviceDescription,
        rate: serviceRate ? parseInt(serviceRate) : undefined,
        rateType: serviceRateType,
        portfolioURL: servicePortfolioUrl || undefined,
        borough: serviceBorough || undefined,
      })
      router.push('/gigs?tab=services')
    } catch (error) {
      console.error('Error creating service:', error)
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleCreateFlyer = async () => {
    if (!flyerTitle || !flyerVenue || !flyerDate) return
    if (!user || !profile) return

    setIsSubmitting(true)
    try {
      const eventDate = new Date(`${flyerDate}${flyerTime ? `T${flyerTime}` : 'T20:00'}`)

      await createShowFlyer.mutateAsync({
        authorUID: user.uid,
        authorUsername: profile.username || '',
        title: flyerTitle,
        venue: flyerVenue,
        eventDate,
        description: flyerDescription || undefined,
        ticketURL: flyerTicketUrl || undefined,
        borough: flyerBorough || undefined,
        photos: flyerPhotos,
      })
      router.push('/gigs?tab=shows')
    } catch (error) {
      console.error('Error creating flyer:', error)
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleSubmit = () => {
    if (activeTab === 'iso') handleCreateISO()
    else if (activeTab === 'service') handleCreateService()
    else if (activeTab === 'flyer') handleCreateFlyer()
  }

  const isValid = () => {
    if (activeTab === 'iso') return !!isoRole && !!isoDescription
    if (activeTab === 'service') return !!serviceTitle && !!serviceCategory && !!serviceDescription
    if (activeTab === 'flyer') return !!flyerTitle && !!flyerVenue && !!flyerDate
    return false
  }

  return (
    <div className="max-w-2xl mx-auto px-4 md:px-8 py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <Link href="/gigs" className="text-muted hover:text-ink transition-colors">
            <ArrowLeft size={20} />
          </Link>
          <h1 className="font-mono text-lg font-bold uppercase tracking-tight">Create Post</h1>
        </div>
        <Button
          onClick={handleSubmit}
          isLoading={isSubmitting}
          disabled={!isValid()}
        >
          Post
        </Button>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 border-b border-dim mb-6">
        {[
          { id: 'iso' as const, label: 'ISO Post', icon: Music },
          { id: 'service' as const, label: 'Service', icon: FileText },
          { id: 'flyer' as const, label: 'Show Flyer', icon: ImageIcon },
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={clsx(
              'flex items-center gap-1.5 px-4 py-2 font-mono text-xs uppercase tracking-wider transition-colors',
              activeTab === tab.id
                ? 'text-accent border-b-2 border-accent -mb-px'
                : 'text-muted hover:text-ink'
            )}
          >
            <tab.icon size={14} />
            {tab.label}
          </button>
        ))}
      </div>

      {/* ISO Post Form */}
      {activeTab === 'iso' && (
        <div className="space-y-4">
          <Card>
            <h2 className="font-mono text-xs uppercase tracking-wider text-muted mb-4">
              Looking For
            </h2>

            <div className="mb-4">
              <label className="block font-mono text-xs uppercase tracking-wider text-muted mb-2">
                Role *
              </label>
              <div className="flex flex-wrap gap-2">
                {ISO_ROLES.map((role) => (
                  <button
                    key={role}
                    onClick={() => setIsoRole(role)}
                    className={clsx(
                      'px-3 py-1.5 font-mono text-xs uppercase tracking-wider border transition-colors',
                      isoRole === role
                        ? 'bg-accent text-paper border-accent'
                        : 'bg-transparent text-muted border-dim hover:border-muted'
                    )}
                  >
                    {role}
                  </button>
                ))}
              </div>
            </div>

            <div className="mb-4">
              <label className="block font-mono text-xs uppercase tracking-wider text-muted mb-2">
                Genre (optional)
              </label>
              <div className="flex flex-wrap gap-2">
                {GENRES.map((genre) => (
                  <button
                    key={genre}
                    onClick={() => setIsoGenre(isoGenre === genre ? '' : genre)}
                    className={clsx(
                      'px-3 py-1.5 font-mono text-xs uppercase tracking-wider border transition-colors',
                      isoGenre === genre
                        ? 'bg-accent text-paper border-accent'
                        : 'bg-transparent text-muted border-dim hover:border-muted'
                    )}
                  >
                    {genre}
                  </button>
                ))}
              </div>
            </div>
          </Card>

          <Textarea
            label="Description *"
            value={isoDescription}
            onChange={(e) => setIsoDescription(e.target.value)}
            placeholder="Describe what you're looking for, your project, timeline, etc."
            rows={4}
            maxLength={1000}
          />

          <div className="grid grid-cols-2 gap-4">
            <Input
              label="Budget"
              type="number"
              value={isoBudget}
              onChange={(e) => setIsoBudget(e.target.value)}
              placeholder="$"
            />

            <Select
              label="Timeframe"
              value={isoTimeframe}
              onChange={(e) => setIsoTimeframe(e.target.value)}
              options={TIMEFRAMES}
            />
          </div>

          <Select
            label="Borough"
            value={isoBorough}
            onChange={(e) => setIsoBorough(e.target.value)}
            options={[
              { value: '', label: 'Any' },
              ...BOROUGHS.map((b) => ({ value: b, label: b })),
            ]}
          />
        </div>
      )}

      {/* Service Listing Form */}
      {activeTab === 'service' && (
        <div className="space-y-4">
          <Input
            label="Title *"
            value={serviceTitle}
            onChange={(e) => setServiceTitle(e.target.value)}
            placeholder="e.g., Mixing & Mastering Services"
          />

          <Card>
            <label className="block font-mono text-xs uppercase tracking-wider text-muted mb-2">
              Category *
            </label>
            <div className="flex flex-wrap gap-2">
              {SERVICE_CATEGORIES.map((cat) => (
                <button
                  key={cat}
                  onClick={() => setServiceCategory(cat)}
                  className={clsx(
                    'px-3 py-1.5 font-mono text-xs uppercase tracking-wider border transition-colors',
                    serviceCategory === cat
                      ? 'bg-accent text-paper border-accent'
                      : 'bg-transparent text-muted border-dim hover:border-muted'
                  )}
                >
                  {cat}
                </button>
              ))}
            </div>
          </Card>

          <Textarea
            label="Description *"
            value={serviceDescription}
            onChange={(e) => setServiceDescription(e.target.value)}
            placeholder="Describe your service, experience, equipment, etc."
            rows={4}
            maxLength={1000}
          />

          <div className="grid grid-cols-2 gap-4">
            <Input
              label="Rate"
              type="number"
              value={serviceRate}
              onChange={(e) => setServiceRate(e.target.value)}
              placeholder="$"
            />

            <Select
              label="Rate Type"
              value={serviceRateType}
              onChange={(e) => setServiceRateType(e.target.value as any)}
              options={[
                { value: 'hourly', label: 'Per Hour' },
                { value: 'flat', label: 'Flat Rate' },
                { value: 'negotiable', label: 'Negotiable' },
              ]}
            />
          </div>

          <Input
            label="Portfolio URL"
            value={servicePortfolioUrl}
            onChange={(e) => setServicePortfolioUrl(e.target.value)}
            placeholder="https://your-portfolio.com"
          />

          <Select
            label="Borough"
            value={serviceBorough}
            onChange={(e) => setServiceBorough(e.target.value)}
            options={[
              { value: '', label: 'Any' },
              ...BOROUGHS.map((b) => ({ value: b, label: b })),
            ]}
          />
        </div>
      )}

      {/* Show Flyer Form */}
      {activeTab === 'flyer' && (
        <div className="space-y-4">
          <PhotoUploader
            photos={flyerPhotos}
            onChange={setFlyerPhotos}
            maxPhotos={1}
          />

          <Input
            label="Event Title *"
            value={flyerTitle}
            onChange={(e) => setFlyerTitle(e.target.value)}
            placeholder="e.g., Warehouse Show w/ Local Bands"
          />

          <Input
            label="Venue *"
            value={flyerVenue}
            onChange={(e) => setFlyerVenue(e.target.value)}
            placeholder="e.g., Market Hotel"
          />

          <div className="grid grid-cols-2 gap-4">
            <Input
              label="Date *"
              type="date"
              value={flyerDate}
              onChange={(e) => setFlyerDate(e.target.value)}
            />

            <Input
              label="Time"
              type="time"
              value={flyerTime}
              onChange={(e) => setFlyerTime(e.target.value)}
            />
          </div>

          <Textarea
            label="Description"
            value={flyerDescription}
            onChange={(e) => setFlyerDescription(e.target.value)}
            placeholder="Line-up, ticket info, etc."
            rows={3}
            maxLength={500}
          />

          <Input
            label="Ticket URL"
            value={flyerTicketUrl}
            onChange={(e) => setFlyerTicketUrl(e.target.value)}
            placeholder="https://tickets.com/..."
          />

          <Select
            label="Borough"
            value={flyerBorough}
            onChange={(e) => setFlyerBorough(e.target.value)}
            options={[
              { value: '', label: 'Select' },
              ...BOROUGHS.map((b) => ({ value: b, label: b })),
            ]}
          />
        </div>
      )}
    </div>
  )
}
