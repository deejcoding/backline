'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { Ticket, User } from 'lucide-react'
import { useAuthStore } from '@/lib/stores/authStore'
import { Button, Input, Card } from '@/components/ui'

export default function CompleteRegistrationPage() {
  const router = useRouter()
  const {
    user,
    needsUsername,
    needsReferralCode,
    completeSocialRegistration,
    isLoading,
    errorMessage,
    setError,
  } = useAuthStore()

  const [username, setUsername] = useState('')
  const [referralCode, setReferralCode] = useState('')

  useEffect(() => {
    // If user is not logged in, redirect to login
    if (!user) {
      router.push('/login')
    }
    // If registration is complete, redirect to home or onboarding
    if (user && !needsUsername && !needsReferralCode) {
      router.push('/onboarding')
    }
  }, [user, needsUsername, needsReferralCode, router])

  // Clear error on unmount
  useEffect(() => {
    return () => setError(null)
  }, [setError])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    await completeSocialRegistration(username, referralCode)
  }

  if (!user || (!needsUsername && !needsReferralCode)) {
    return (
      <div className="min-h-[calc(100vh-65px)] flex items-center justify-center p-4">
        <div className="flex items-center gap-3 text-muted font-mono text-sm">
          <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full spinner" />
          Loading...
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-[calc(100vh-65px)] flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="font-mono text-2xl font-bold uppercase tracking-tight mb-2">
            Complete Your Profile
          </h1>
          <p className="font-mono text-sm text-muted">
            Just a few more details to get started
          </p>
        </div>

        <Card>
          <form onSubmit={handleSubmit} className="space-y-4">
            {needsUsername && (
              <div>
                <Input
                  label="Username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, ''))}
                  placeholder="yourhandle"
                  maxLength={20}
                  autoComplete="username"
                />
                <p className="font-mono text-[10px] text-muted mt-1">
                  3-20 characters, letters, numbers, and underscores only
                </p>
              </div>
            )}

            {needsReferralCode && (
              <div>
                <Input
                  label="Referral Code"
                  value={referralCode}
                  onChange={(e) => setReferralCode(e.target.value.toUpperCase())}
                  placeholder="ABCD1234"
                  maxLength={20}
                />
                <p className="font-mono text-[10px] text-muted mt-1">
                  Enter a referral code from an existing member
                </p>
              </div>
            )}

            {errorMessage && (
              <p className="font-mono text-xs text-signal-red text-center">
                {errorMessage}
              </p>
            )}

            <Button
              type="submit"
              isLoading={isLoading}
              disabled={
                (needsUsername && username.length < 3) ||
                (needsReferralCode && referralCode.length < 4)
              }
              className="w-full"
            >
              Continue
            </Button>
          </form>
        </Card>

        <div className="mt-6 text-center">
          <p className="font-mono text-xs text-muted">
            Don't have a referral code?{' '}
            <a
              href="https://instagram.com/backlinenyc"
              target="_blank"
              rel="noopener noreferrer"
              className="text-accent hover:underline"
            >
              Request one on Instagram
            </a>
          </p>
        </div>
      </div>
    </div>
  )
}
