'use client'

import clsx from 'clsx'

interface BadgeProps {
  children: React.ReactNode
  variant?: 'default' | 'accent' | 'success' | 'warning' | 'danger'
  className?: string
}

export function Badge({ children, variant = 'default', className }: BadgeProps) {
  const variants = {
    default: 'bg-soft border-dim text-muted',
    accent: 'bg-accent/10 border-accent text-accent',
    success: 'bg-signal-green/10 border-signal-green text-signal-green',
    warning: 'bg-signal-yellow/10 border-signal-yellow text-signal-yellow',
    danger: 'bg-signal-red/10 border-signal-red text-signal-red',
  }

  return (
    <span
      className={clsx(
        'inline-flex items-center px-2 py-0.5 border font-mono text-[10px] tracking-wider uppercase',
        variants[variant],
        className
      )}
    >
      {children}
    </span>
  )
}
