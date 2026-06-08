'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

// Site is read-only, redirect to profile
export default function EditProfilePage() {
  const router = useRouter()

  useEffect(() => {
    router.replace('/profile')
  }, [router])

  return (
    <div className="min-h-screen flex items-center justify-center pb-20">
      <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
    </div>
  )
}
