'use client'

import { useState } from 'react'
import Image from 'next/image'
import { ChevronLeft, ChevronRight, X } from 'lucide-react'
import clsx from 'clsx'

interface PhotoCarouselProps {
  photos: string[]
  alt: string
}

export function PhotoCarousel({ photos, alt }: PhotoCarouselProps) {
  const [currentIndex, setCurrentIndex] = useState(0)
  const [isFullscreen, setIsFullscreen] = useState(false)

  if (photos.length === 0) {
    return (
      <div className="aspect-square bg-soft border border-dim flex items-center justify-center">
        <span className="font-mono text-sm text-muted">No photos</span>
      </div>
    )
  }

  const goToPrev = () => {
    setCurrentIndex((prev) => (prev === 0 ? photos.length - 1 : prev - 1))
  }

  const goToNext = () => {
    setCurrentIndex((prev) => (prev === photos.length - 1 ? 0 : prev + 1))
  }

  return (
    <>
      <div className="relative">
        {/* Main Image */}
        <div
          className="relative aspect-square bg-soft border border-dim cursor-pointer overflow-hidden"
          onClick={() => setIsFullscreen(true)}
        >
          <Image
            src={photos[currentIndex]}
            alt={`${alt} - Photo ${currentIndex + 1}`}
            fill
            className="object-contain"
            sizes="(max-width: 768px) 100vw, 50vw"
            priority
          />
        </div>

        {/* Navigation Arrows */}
        {photos.length > 1 && (
          <>
            <button
              onClick={(e) => {
                e.stopPropagation()
                goToPrev()
              }}
              className="absolute left-2 top-1/2 -translate-y-1/2 w-8 h-8 flex items-center justify-center bg-paper/80 border border-dim text-ink hover:bg-paper transition-colors"
            >
              <ChevronLeft size={18} />
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation()
                goToNext()
              }}
              className="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 flex items-center justify-center bg-paper/80 border border-dim text-ink hover:bg-paper transition-colors"
            >
              <ChevronRight size={18} />
            </button>
          </>
        )}

        {/* Dots */}
        {photos.length > 1 && (
          <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-1.5">
            {photos.map((_, idx) => (
              <button
                key={idx}
                onClick={(e) => {
                  e.stopPropagation()
                  setCurrentIndex(idx)
                }}
                className={clsx(
                  'w-2 h-2 rounded-full transition-colors',
                  idx === currentIndex ? 'bg-ink' : 'bg-muted'
                )}
              />
            ))}
          </div>
        )}
      </div>

      {/* Thumbnails */}
      {photos.length > 1 && (
        <div className="flex gap-2 mt-2 overflow-x-auto hide-scrollbar">
          {photos.map((photo, idx) => (
            <button
              key={idx}
              onClick={() => setCurrentIndex(idx)}
              className={clsx(
                'relative w-16 h-16 flex-shrink-0 bg-soft border overflow-hidden',
                idx === currentIndex ? 'border-accent' : 'border-dim'
              )}
            >
              <Image
                src={photo}
                alt={`Thumbnail ${idx + 1}`}
                fill
                className="object-cover"
                sizes="64px"
              />
            </button>
          ))}
        </div>
      )}

      {/* Fullscreen Modal */}
      {isFullscreen && (
        <div
          className="fixed inset-0 z-50 bg-paper flex items-center justify-center"
          onClick={() => setIsFullscreen(false)}
        >
          <button
            className="absolute top-4 right-4 w-10 h-10 flex items-center justify-center text-muted hover:text-ink transition-colors"
            onClick={() => setIsFullscreen(false)}
          >
            <X size={24} />
          </button>

          <div className="relative w-full h-full max-w-4xl max-h-[90vh] m-4">
            <Image
              src={photos[currentIndex]}
              alt={`${alt} - Photo ${currentIndex + 1}`}
              fill
              className="object-contain"
              sizes="100vw"
            />
          </div>

          {photos.length > 1 && (
            <>
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  goToPrev()
                }}
                className="absolute left-4 top-1/2 -translate-y-1/2 w-12 h-12 flex items-center justify-center bg-soft border border-dim text-ink hover:bg-dim transition-colors"
              >
                <ChevronLeft size={24} />
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  goToNext()
                }}
                className="absolute right-4 top-1/2 -translate-y-1/2 w-12 h-12 flex items-center justify-center bg-soft border border-dim text-ink hover:bg-dim transition-colors"
              >
                <ChevronRight size={24} />
              </button>
            </>
          )}
        </div>
      )}
    </>
  )
}
