import Link from 'next/link'
import { Apple, ArrowLeft } from 'lucide-react'

const APP_STORE_URL = 'https://apps.apple.com/app/backline-nyc/id6504419947'

export default function SignUpPage() {
  return (
    <div className="min-h-[calc(100vh-65px)] flex items-center justify-center p-4">
      <div className="w-full max-w-sm text-center">
        <Link href="/" className="inline-flex items-center gap-1 text-sm text-white/50 hover:text-white mb-8">
          <ArrowLeft size={16} /> Back to browsing
        </Link>

        <h1 className="font-mono text-2xl font-bold uppercase tracking-tight mb-3">
          Join Backline
        </h1>
        <p className="text-sm text-white/60 mb-8">
          Create your account and connect with NYC musicians on our iOS app. Full web functionality coming soon.
        </p>

        <a
          href={APP_STORE_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center justify-center gap-2 w-full px-4 py-3 bg-white text-black font-mono text-sm font-semibold uppercase tracking-wider hover:opacity-90 transition-opacity"
        >
          <Apple size={18} /> Download on the App Store
        </a>

        <p className="text-xs text-white/40 mt-6">
          Available for iPhone and iPad
        </p>
      </div>
    </div>
  )
}
