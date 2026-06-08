'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  Home,
  Music,
  ShoppingBag,
  MessageSquare,
  User,
  Settings,
  Users,
  FileText,
  Bell,
} from 'lucide-react'
import clsx from 'clsx'
import { useAuthStore } from '@/lib/stores/authStore'
import { Avatar } from '@/components/ui'

const mainNavItems = [
  { href: '/', label: 'Home', icon: Home },
  { href: '/gigs', label: 'Gigs', icon: Music },
  { href: '/market', label: 'Market', icon: ShoppingBag },
]

const userNavItems = [
  { href: '/messages', label: 'Messages', icon: MessageSquare },
  { href: '/profile', label: 'My Profile', icon: User },
  { href: '/profile/connections', label: 'Connections', icon: Users },
]

export function Sidebar() {
  const pathname = usePathname()
  const { user, profile, isGuestMode } = useAuthStore()

  const isAuthenticated = !!user && !isGuestMode

  return (
    <aside className="hidden lg:flex flex-col w-56 border-r border-dim min-h-[calc(100vh-65px)] p-4">
      {/* Main Nav */}
      <nav className="flex flex-col gap-1">
        {mainNavItems.map((item) => {
          const Icon = item.icon
          const isActive = pathname === item.href

          return (
            <Link
              key={item.href}
              href={item.href}
              className={clsx(
                'flex items-center gap-3 px-3 py-2 font-mono text-xs uppercase tracking-wider transition-colors',
                isActive
                  ? 'text-ink bg-soft'
                  : 'text-muted hover:text-ink hover:bg-soft/50'
              )}
            >
              <Icon size={16} />
              {item.label}
            </Link>
          )
        })}
      </nav>

      {/* Divider */}
      <div className="h-px bg-dim my-4" />

      {/* User Nav (authenticated only) */}
      {isAuthenticated ? (
        <>
          <nav className="flex flex-col gap-1">
            {userNavItems.map((item) => {
              const Icon = item.icon
              const isActive = pathname === item.href

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={clsx(
                    'flex items-center gap-3 px-3 py-2 font-mono text-xs uppercase tracking-wider transition-colors',
                    isActive
                      ? 'text-ink bg-soft'
                      : 'text-muted hover:text-ink hover:bg-soft/50'
                  )}
                >
                  <Icon size={16} />
                  {item.label}
                </Link>
              )
            })}
          </nav>

          {/* User card at bottom */}
          <div className="mt-auto pt-4">
            <Link
              href="/profile"
              className="flex items-center gap-3 p-3 bg-soft border border-dim hover:border-muted transition-colors"
            >
              <Avatar src={profile?.profilePhotoURL} size="sm" />
              <div className="flex-1 min-w-0">
                <p className="font-mono text-xs text-ink truncate">
                  @{profile?.username || 'user'}
                </p>
                {profile?.displayName && (
                  <p className="font-mono text-[10px] text-muted truncate">
                    {profile.displayName}
                  </p>
                )}
              </div>
            </Link>
          </div>
        </>
      ) : (
        <div className="flex flex-col gap-2 mt-auto">
          <Link
            href="/login"
            className="text-center py-2 font-mono text-xs uppercase tracking-wider text-muted hover:text-ink transition-colors"
          >
            Login
          </Link>
          <Link
            href="/signup"
            className="text-center py-2 bg-accent text-paper font-mono text-xs uppercase tracking-wider font-semibold hover:opacity-85 transition-opacity"
          >
            Sign Up
          </Link>
        </div>
      )}
    </aside>
  )
}
