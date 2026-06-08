'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { Button, Input } from '@/components/ui'
import { useAuthStore } from '@/lib/stores/authStore'
import { SocialAuth } from './SocialAuth'

export function LoginForm() {
  const router = useRouter()
  const { signIn, isLoading, errorMessage, setError } = useAuthStore()
  const [emailOrUsername, setEmailOrUsername] = useState('')
  const [password, setPassword] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!emailOrUsername || !password) {
      setError('Please fill in all fields')
      return
    }

    await signIn(emailOrUsername, password)

    // Redirect on success (auth state change will trigger in provider)
    if (!useAuthStore.getState().errorMessage) {
      router.push('/')
    }
  }

  return (
    <div className="w-full max-w-sm mx-auto">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input
          label="Email or Username"
          type="text"
          value={emailOrUsername}
          onChange={(e) => setEmailOrUsername(e.target.value)}
          placeholder="you@example.com"
          autoComplete="username"
        />

        <Input
          label="Password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="••••••••"
          autoComplete="current-password"
        />

        {errorMessage && (
          <p className="font-mono text-xs text-signal-red">{errorMessage}</p>
        )}

        <Button type="submit" isLoading={isLoading} className="w-full mt-2">
          Sign In
        </Button>

        <Link
          href="/forgot-password"
          className="text-center font-mono text-xs text-muted hover:text-ink transition-colors"
        >
          Forgot password?
        </Link>
      </form>

      <div className="my-6 flex items-center gap-3">
        <div className="flex-1 h-px bg-dim" />
        <span className="font-mono text-[10px] text-muted uppercase tracking-wider">or</span>
        <div className="flex-1 h-px bg-dim" />
      </div>

      <SocialAuth />

      <p className="mt-6 text-center font-mono text-xs text-muted">
        Don&apos;t have an account?{' '}
        <Link href="/signup" className="text-accent hover:underline">
          Sign up
        </Link>
      </p>
    </div>
  )
}
