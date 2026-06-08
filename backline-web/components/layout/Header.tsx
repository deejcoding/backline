'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { MessageSquare } from 'lucide-react'
import { useAuthStore } from '@/lib/stores/authStore'
import { Avatar } from '@/components/ui'

export function Header() {
  const pathname = usePathname()
  const { user, profile, isGuestMode } = useAuthStore()

  const isAuthenticated = !!user && !isGuestMode

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

        {/* Right side */}
        <div className="flex items-center gap-3">
          {isAuthenticated ? (
            <>
              {/* Messages icon */}
              <Link
                href="/messages"
                className="w-8 h-8 flex items-center justify-center border border-white/20 hover:border-white/40 transition-colors"
              >
                <MessageSquare size={14} />
              </Link>

              {/* Profile - desktop only */}
              <Link href="/profile" className="hidden md:block">
                <Avatar src={profile?.profilePhotoURL} size="sm" />
              </Link>
            </>
          ) : (
            <div className="flex items-center gap-3">
              <Link
                href="/login"
                className="font-mono text-[11px] text-white/60 hover:text-white transition-colors uppercase tracking-wider"
              >
                Login
              </Link>
              <Link
                href="/signup"
                className="px-4 py-2 bg-accent text-black font-mono text-[11px] font-semibold uppercase tracking-wider hover:opacity-85 transition-opacity"
              >
                Sign Up
              </Link>
            </div>
          )}
        </div>
      </div>
    </header>
  )
}
