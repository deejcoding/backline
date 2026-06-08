'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { Button, Input } from '@/components/ui'
import { useAuthStore } from '@/lib/stores/authStore'
import { SocialAuth } from './SocialAuth'

export function SignUpForm() {
  const router = useRouter()
  const { signUp, isLoading, errorMessage, setError } = useAuthStore()
  const [email, setEmail] = useState('')
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [referralCode, setReferralCode] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!email || !username || !password || !referralCode) {
      setError('Please fill in all fields')
      return
    }

    if (password.length < 6) {
      setError('Password must be at least 6 characters')
      return
    }

    if (password !== confirmPassword) {
      setError('Passwords do not match')
      return
    }

    await signUp(email, password, username, referralCode)

    // Redirect on success
    if (!useAuthStore.getState().errorMessage) {
      router.push('/onboarding')
    }
  }

  return (
    <div className="w-full max-w-sm mx-auto">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input
          label="Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@example.com"
          autoComplete="email"
        />

        <Input
          label="Username"
          type="text"
          value={username}
          onChange={(e) => setUsername(e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, ''))}
          placeholder="yourname"
          autoComplete="username"
          maxLength={20}
        />

        <Input
          label="Referral Code"
          type="text"
          value={referralCode}
          onChange={(e) => setReferralCode(e.target.value.toUpperCase())}
          placeholder="XXXXXX"
          maxLength={20}
        />

        <Input
          label="Password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="••••••••"
          autoComplete="new-password"
        />

        <Input
          label="Confirm Password"
          type="password"
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          placeholder="••••••••"
          autoComplete="new-password"
        />

        {errorMessage && (
          <p className="font-mono text-xs text-signal-red">{errorMessage}</p>
        )}

        <Button type="submit" isLoading={isLoading} className="w-full mt-2">
          Create Account
        </Button>
      </form>

      <div className="my-6 flex items-center gap-3">
        <div className="flex-1 h-px bg-dim" />
        <span className="font-mono text-[10px] text-muted uppercase tracking-wider">or</span>
        <div className="flex-1 h-px bg-dim" />
      </div>

      <SocialAuth />

      <p className="mt-6 text-center font-mono text-xs text-muted">
        Already have an account?{' '}
        <Link href="/login" className="text-accent hover:underline">
          Sign in
        </Link>
      </p>
    </div>
  )
}
