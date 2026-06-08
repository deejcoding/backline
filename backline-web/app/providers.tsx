'use client'

import { useEffect, useState } from 'react'
import { useRouter, usePathname } from 'next/navigation'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { onAuthStateChanged } from 'firebase/auth'
import { auth } from '@/lib/firebase/config'
import { useAuthStore } from '@/lib/stores/authStore'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      gcTime: 1000 * 60 * 30, // 30 minutes
      retry: 1,
    },
  },
})

function AuthProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const pathname = usePathname()
  const [isInitialized, setIsInitialized] = useState(false)

  const setUser = useAuthStore((state) => state.setUser)
  const fetchProfile = useAuthStore((state) => state.fetchProfile)
  const needsUsername = useAuthStore((state) => state.needsUsername)
  const needsReferralCode = useAuthStore((state) => state.needsReferralCode)
  const needsOnboarding = useAuthStore((state) => state.needsOnboarding)
  const user = useAuthStore((state) => state.user)

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      setUser(firebaseUser)
      if (firebaseUser) {
        await fetchProfile(firebaseUser.uid)
      }
      setIsInitialized(true)
    })

    return () => unsubscribe()
  }, [setUser, fetchProfile])

  // Handle redirects based on auth state
  useEffect(() => {
    if (!isInitialized) return

    const authPages = ['/login', '/signup', '/forgot-password']
    const isAuthPage = authPages.includes(pathname)
    const isCompleteRegistration = pathname === '/complete-registration'
    const isOnboarding = pathname === '/onboarding'

    if (user) {
      // User needs to complete social registration
      if ((needsUsername || needsReferralCode) && !isCompleteRegistration) {
        router.replace('/complete-registration')
        return
      }

      // User needs onboarding
      if (needsOnboarding && !isOnboarding && !needsUsername && !needsReferralCode) {
        router.replace('/onboarding')
        return
      }

      // Redirect away from auth pages if fully logged in
      if (isAuthPage && !needsUsername && !needsReferralCode) {
        router.replace('/')
        return
      }
    }
  }, [isInitialized, user, needsUsername, needsReferralCode, needsOnboarding, pathname, router])

  // Show loading state while initializing
  if (!isInitialized) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-paper">
        <div className="flex items-center gap-3 text-muted font-mono text-sm">
          <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
          Loading...
        </div>
      </div>
    )
  }

  return <>{children}</>
}

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>{children}</AuthProvider>
    </QueryClientProvider>
  )
}
