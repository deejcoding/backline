'use client'

import { useRef, useState } from 'react'
import Image from 'next/image'
import { Plus, X } from 'lucide-react'
import clsx from 'clsx'

interface PhotoUploaderProps {
  photos: File[]
  existingUrls?: string[]
  onChange: (photos: File[]) => void
  onRemoveExisting?: (url: string) => void
  maxPhotos?: number
}

export function PhotoUploader({
  photos,
  existingUrls = [],
  onChange,
  onRemoveExisting,
  maxPhotos = 6,
}: PhotoUploaderProps) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [previews, setPreviews] = useState<string[]>([])

  const totalPhotos = existingUrls.length + photos.length

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || [])
    const remaining = maxPhotos - totalPhotos
    const newFiles = files.slice(0, remaining)

    // Create previews
    const newPreviews = newFiles.map((file) => URL.createObjectURL(file))
    setPreviews((prev) => [...prev, ...newPreviews])

    onChange([...photos, ...newFiles])

    // Reset input
    if (inputRef.current) {
      inputRef.current.value = ''
    }
  }

  const removePhoto = (index: number) => {
    // Revoke preview URL to prevent memory leak
    URL.revokeObjectURL(previews[index])

    const newPhotos = photos.filter((_, i) => i !== index)
    const newPreviews = previews.filter((_, i) => i !== index)

    setPreviews(newPreviews)
    onChange(newPhotos)
  }

  const removeExisting = (url: string) => {
    onRemoveExisting?.(url)
  }

  return (
    <div className="space-y-2">
      <label className="font-mono text-[10px] tracking-[0.15em] uppercase text-muted">
        Photos ({totalPhotos}/{maxPhotos})
      </label>

      <div className="grid grid-cols-3 gap-2">
        {/* Existing photos */}
        {existingUrls.map((url, idx) => (
          <div
            key={`existing-${idx}`}
            className="relative aspect-square bg-soft border border-dim"
          >
            <Image
              src={url}
              alt={`Photo ${idx + 1}`}
              fill
              className="object-cover"
              sizes="150px"
            />
            <button
              type="button"
              onClick={() => removeExisting(url)}
              className="absolute top-1 right-1 w-6 h-6 flex items-center justify-center bg-paper/80 border border-dim text-muted hover:text-ink transition-colors"
            >
              <X size={14} />
            </button>
          </div>
        ))}

        {/* New photos */}
        {photos.map((file, idx) => (
          <div
            key={`new-${idx}`}
            className="relative aspect-square bg-soft border border-dim"
          >
            <Image
              src={previews[idx] || ''}
              alt={`New photo ${idx + 1}`}
              fill
              className="object-cover"
              sizes="150px"
            />
            <button
              type="button"
              onClick={() => removePhoto(idx)}
              className="absolute top-1 right-1 w-6 h-6 flex items-center justify-center bg-paper/80 border border-dim text-muted hover:text-ink transition-colors"
            >
              <X size={14} />
            </button>
          </div>
        ))}

        {/* Add button */}
        {totalPhotos < maxPhotos && (
          <button
            type="button"
            onClick={() => inputRef.current?.click()}
            className="aspect-square bg-soft border border-dim border-dashed flex flex-col items-center justify-center text-muted hover:text-ink hover:border-muted transition-colors"
          >
            <Plus size={24} />
            <span className="font-mono text-[10px] mt-1">Add</span>
          </button>
        )}
      </div>

      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        multiple
        onChange={handleFileSelect}
        className="hidden"
      />
    </div>
  )
}
