'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Apple } from 'lucide-react'

const APP_STORE_URL = 'https://apps.apple.com/app/backline-nyc/id6504419947'

export function Header() {
  const pathname = usePathname()

  // Hide header on auth pages
  if (pathname.startsWith('/login') || pathname.startsWith('/signup') || pathname.startsWith('/forgot-password') || pathname.startsWith('/onboarding')) {
    return null
  }

  return (
    <header className="border-b border-white/10">
      <div className="px-4 py-3 flex items-center justify-between">
        {/* Logo */}
        <Link href="/" className="font-mono font-bold text-lg tracking-tight">
          backline
        </Link>

        {/* Right side - App Store link */}
        <a
          href={APP_STORE_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-1.5 px-3 py-1.5 bg-white text-black font-mono text-[11px] font-semibold uppercase tracking-wider hover:opacity-85 transition-opacity"
        >
          <Apple size={14} /> Get the App
        </a>
      </div>
    </header>
  )
}
