'use client'

import Image from 'next/image'
import clsx from 'clsx'
import { User } from 'lucide-react'

interface AvatarProps {
  src?: string | null
  alt?: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  className?: string
}

const sizes = {
  sm: 'w-8 h-8',
  md: 'w-10 h-10',
  lg: 'w-16 h-16',
  xl: 'w-24 h-24',
}

const iconSizes = {
  sm: 14,
  md: 18,
  lg: 28,
  xl: 42,
}

export function Avatar({ src, alt = 'Profile', size = 'md', className }: AvatarProps) {
  return (
    <div
      className={clsx(
        'relative rounded-full overflow-hidden bg-soft border border-dim flex items-center justify-center',
        sizes[size],
        className
      )}
    >
      {src ? (
        <Image
          src={src}
          alt={alt}
          fill
          className="object-cover"
          sizes={size === 'xl' ? '96px' : size === 'lg' ? '64px' : size === 'md' ? '40px' : '32px'}
        />
      ) : (
        <User size={iconSizes[size]} className="text-muted" />
      )}
    </div>
  )
}
