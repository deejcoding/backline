'use client'

import { useEffect } from 'react'
import { X, CheckCircle, AlertCircle, Info } from 'lucide-react'
import clsx from 'clsx'
import { useUIStore } from '@/lib/stores/uiStore'

export function Toast() {
  const { toastMessage, toastType, hideToast } = useUIStore()

  if (!toastMessage) return null

  const icons = {
    success: <CheckCircle size={18} className="text-signal-green" />,
    error: <AlertCircle size={18} className="text-signal-red" />,
    info: <Info size={18} className="text-accent" />,
  }

  const borders = {
    success: 'border-signal-green',
    error: 'border-signal-red',
    info: 'border-accent',
  }

  return (
    <div className="fixed bottom-4 right-4 z-50 animate-in slide-in-from-bottom-4 fade-in duration-300">
      <div
        className={clsx(
          'flex items-center gap-3 bg-soft border px-4 py-3 shadow-lg',
          borders[toastType]
        )}
      >
        {icons[toastType]}
        <span className="font-mono text-sm text-ink">{toastMessage}</span>
        <button
          onClick={hideToast}
          className="text-muted hover:text-ink transition-colors ml-2"
        >
          <X size={16} />
        </button>
      </div>
    </div>
  )
}
