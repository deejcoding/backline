'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Button, Input } from '@/components/ui'
import { useAuthStore } from '@/lib/stores/authStore'

export default function ForgotPasswordPage() {
  const { resetPassword, isLoading, errorMessage, setError } = useAuthStore()
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!email) {
      setError('Please enter your email')
      return
    }

    await resetPassword(email)
    setSent(true)
  }

  return (
    <div className="min-h-[calc(100vh-65px)] flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="font-mono text-2xl font-bold uppercase tracking-tight mb-2">
            Reset Password
          </h1>
          <p className="font-mono text-sm text-muted">
            Enter your email and we&apos;ll send you a reset link
          </p>
        </div>

        {sent ? (
          <div className="text-center">
            <p className="font-mono text-sm text-signal-green mb-4">
              Check your email for a password reset link.
            </p>
            <Link
              href="/login"
              className="font-mono text-sm text-accent hover:underline"
            >
              Back to login
            </Link>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="flex flex-col gap-4">
            <Input
              label="Email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
              autoComplete="email"
            />

            {errorMessage && (
              <p className="font-mono text-xs text-signal-red">{errorMessage}</p>
            )}

            <Button type="submit" isLoading={isLoading} className="w-full mt-2">
              Send Reset Link
            </Button>

            <Link
              href="/login"
              className="text-center font-mono text-xs text-muted hover:text-ink transition-colors"
            >
              Back to login
            </Link>
          </form>
        )}
      </div>
    </div>
  )
}
