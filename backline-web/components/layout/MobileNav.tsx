'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Home, Users, ShoppingBag, User } from 'lucide-react'
import clsx from 'clsx'
import { useAuthStore } from '@/lib/stores/authStore'

export function MobileNav() {
  const pathname = usePathname()
  const { user, isGuestMode } = useAuthStore()

  const isAuthenticated = !!user && !isGuestMode

  // Don't show on auth pages
  if (pathname.startsWith('/login') || pathname.startsWith('/signup') || pathname.startsWith('/forgot-password') || pathname.startsWith('/onboarding')) {
    return null
  }

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-[#0A0A0A] md:hidden z-40 pb-[env(safe-area-inset-bottom)]">
      <div className="border-t border-white/10">
        <div className="flex items-stretch">
          {/* Home */}
          <TabButton
            href="/"
            icon={Home}
            label="Home"
            isActive={pathname === '/'}
          />

          {/* Gigs */}
          <TabButton
            href="/gigs"
            icon={Users}
            label="Gigs"
            isActive={pathname.startsWith('/gigs')}
          />

          {/* Market */}
          <TabButton
            href="/market"
            icon={ShoppingBag}
            label="Market"
            isActive={pathname.startsWith('/market')}
          />

          {/* Profile / Login */}
          {isAuthenticated ? (
            <TabButton
              href="/profile"
              icon={User}
              label="Profile"
              isActive={pathname.startsWith('/profile') || pathname.startsWith('/u/')}
            />
          ) : (
            <TabButton
              href="/login"
              icon={User}
              label="Login"
              isActive={pathname === '/login'}
            />
          )}
        </div>
      </div>
    </nav>
  )
}

function TabButton({
  href,
  icon: Icon,
  label,
  isActive,
}: {
  href: string
  icon: typeof Home
  label: string
  isActive: boolean
}) {
  return (
    <Link href={href} className="flex-1 relative">
      {/* Active indicator */}
      {isActive && (
        <div className="absolute top-0 left-4 right-4 h-0.5 bg-accent" />
      )}

      <div className={clsx(
        'flex flex-col items-center gap-1 pt-2.5 pb-6',
        isActive ? 'opacity-100' : 'opacity-45'
      )}>
        <Icon size={18} className="text-white" />
        <span className="font-sans text-[10px] tracking-wide text-white">
          {label}
        </span>
      </div>
    </Link>
  )
}
