'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Home, Users, ShoppingBag, Apple } from 'lucide-react'
import clsx from 'clsx'

const APP_STORE_URL = 'https://apps.apple.com/app/backline-nyc/id6504419947'

export function MobileNav() {
  const pathname = usePathname()

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

          {/* Get App */}
          <ExternalTabButton
            href={APP_STORE_URL}
            icon={Apple}
            label="Get App"
          />
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

function ExternalTabButton({
  href,
  icon: Icon,
  label,
}: {
  href: string
  icon: typeof Home
  label: string
}) {
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" className="flex-1">
      <div className="flex flex-col items-center gap-1 pt-2.5 pb-6 opacity-45">
        <Icon size={18} className="text-white" />
        <span className="font-sans text-[10px] tracking-wide text-white">
          {label}
        </span>
      </div>
    </a>
  )
}
