'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { useCreateListing } from '@/lib/hooks/useListings'
import { useAuthStore } from '@/lib/stores/authStore'
import { Button, Input, Textarea, Select } from '@/components/ui'
import { PhotoUploader } from '@/components/listings/PhotoUploader'
import { LISTING_CATEGORIES, LISTING_CONDITIONS, BOROUGHS } from '@/lib/types'
import type { ListingCategory, ListingCondition, ListingType, Borough } from '@/lib/types'

export default function CreateListingPage() {
  const router = useRouter()
  const { user, profile, isGuestMode } = useAuthStore()
  const createListing = useCreateListing()

  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [price, setPrice] = useState('')
  const [rentPrice, setRentPrice] = useState('')
  const [listingTypes, setListingTypes] = useState<ListingType[]>(['Sell'])
  const [category, setCategory] = useState<ListingCategory>('Guitars')
  const [condition, setCondition] = useState<ListingCondition>('Good')
  const [location, setLocation] = useState('')
  const [borough, setBorough] = useState<Borough | ''>('')
  const [photos, setPhotos] = useState<File[]>([])
  const [error, setError] = useState<string | null>(null)

  const isAuthenticated = !!user && !isGuestMode

  if (!isAuthenticated) {
    return (
      <div className="max-w-[1280px] mx-auto px-4 md:px-8 py-12 text-center">
        <p className="font-mono text-muted mb-4">Please sign in to create a listing</p>
        <Link href="/login">
          <Button>Sign In</Button>
        </Link>
      </div>
    )
  }

  const toggleListingType = (type: ListingType) => {
    if (listingTypes.includes(type)) {
      if (listingTypes.length > 1) {
        setListingTypes(listingTypes.filter((t) => t !== type))
      }
    } else {
      setListingTypes([...listingTypes, type])
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!title.trim()) {
      setError('Title is required')
      return
    }
    if (!description.trim()) {
      setError('Description is required')
      return
    }
    if (photos.length === 0) {
      setError('At least one photo is required')
      return
    }
    if (!location.trim()) {
      setError('Location is required')
      return
    }

    try {
      await createListing.mutateAsync({
        title: title.trim(),
        description: description.trim(),
        price: price ? parseFloat(price) : undefined,
        rentPrice: rentPrice || undefined,
        listingTypes,
        category,
        condition,
        location: location.trim(),
        borough: borough || undefined,
        photos,
        sellerUID: user!.uid,
        sellerUsername: profile?.username || 'user',
      })

      router.push('/market')
    } catch (err: any) {
      setError(err.message || 'Failed to create listing')
    }
  }

  return (
    <div className="max-w-2xl mx-auto px-4 md:px-8 py-6">
      {/* Header */}
      <div className="mb-6">
        <Link
          href="/market"
          className="inline-flex items-center gap-2 font-mono text-xs text-muted hover:text-ink transition-colors mb-4"
        >
          ← Back to Market
        </Link>
        <h1 className="font-mono text-xl font-bold uppercase tracking-tight">
          Create Listing
        </h1>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Photos */}
        <PhotoUploader photos={photos} onChange={setPhotos} />

        {/* Title */}
        <Input
          label="Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="e.g., Fender Stratocaster American Professional II"
          maxLength={100}
        />

        {/* Description */}
        <Textarea
          label="Description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Describe your item, include any relevant details about condition, history, etc."
          rows={4}
        />

        {/* Category & Condition */}
        <div className="grid grid-cols-2 gap-4">
          <Select
            label="Category"
            value={category}
            onChange={(e) => setCategory(e.target.value as ListingCategory)}
            options={LISTING_CATEGORIES.map((c) => ({ value: c, label: c }))}
          />
          <Select
            label="Condition"
            value={condition}
            onChange={(e) => setCondition(e.target.value as ListingCondition)}
            options={LISTING_CONDITIONS.map((c) => ({ value: c, label: c }))}
          />
        </div>

        {/* Listing Type */}
        <div>
          <label className="font-mono text-[10px] tracking-[0.15em] uppercase text-muted block mb-2">
            Listing Type
          </label>
          <div className="flex gap-2">
            {(['Sell', 'Rent'] as ListingType[]).map((type) => (
              <button
                key={type}
                type="button"
                onClick={() => toggleListingType(type)}
                className={`px-4 py-2 font-mono text-xs uppercase tracking-wider border transition-colors ${
                  listingTypes.includes(type)
                    ? 'bg-accent text-paper border-accent'
                    : 'bg-transparent text-muted border-dim hover:border-muted'
                }`}
              >
                {type}
              </button>
            ))}
          </div>
        </div>

        {/* Price */}
        <div className="grid grid-cols-2 gap-4">
          {listingTypes.includes('Sell') && (
            <Input
              label="Price ($)"
              type="number"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
              placeholder="0"
              min="0"
            />
          )}
          {listingTypes.includes('Rent') && (
            <Input
              label="Rent Price"
              value={rentPrice}
              onChange={(e) => setRentPrice(e.target.value)}
              placeholder="e.g., $50/day"
            />
          )}
        </div>

        {/* Location */}
        <div className="grid grid-cols-2 gap-4">
          <Input
            label="Location"
            value={location}
            onChange={(e) => setLocation(e.target.value)}
            placeholder="e.g., Bushwick"
          />
          <Select
            label="Borough (optional)"
            value={borough}
            onChange={(e) => setBorough(e.target.value as Borough | '')}
            options={[
              { value: '', label: 'Select borough' },
              ...BOROUGHS.map((b) => ({ value: b, label: b })),
            ]}
          />
        </div>

        {/* Error */}
        {error && <p className="font-mono text-xs text-signal-red">{error}</p>}

        {/* Submit */}
        <Button
          type="submit"
          isLoading={createListing.isPending}
          className="w-full"
        >
          Create Listing
        </Button>
      </form>
    </div>
  )
}
