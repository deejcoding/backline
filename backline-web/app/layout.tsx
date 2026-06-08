import type { Metadata } from 'next'
import './globals.css'
import { Providers } from './providers'
import { Header, MobileNav } from '@/components/layout'
import { Toast } from '@/components/ui'

export const metadata: Metadata = {
  title: 'Backline - NYC Music Community',
  description: 'Connect with musicians, find gigs, and buy/sell gear in NYC.',
  keywords: ['musicians', 'NYC', 'music', 'gigs', 'gear', 'marketplace', 'community'],
  openGraph: {
    title: 'Backline - NYC Music Community',
    description: 'Connect with musicians, find gigs, and buy/sell gear in NYC.',
    type: 'website',
    locale: 'en_US',
    siteName: 'Backline',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Backline - NYC Music Community',
    description: 'Connect with musicians, find gigs, and buy/sell gear in NYC.',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="bg-paper text-ink font-sans">
        <Providers>
          <div className="min-h-screen flex flex-col">
            <Header />
            <main className="flex-1 has-mobile-nav">{children}</main>
            <MobileNav />
            <Toast />
          </div>
        </Providers>
      </body>
    </html>
  )
}
