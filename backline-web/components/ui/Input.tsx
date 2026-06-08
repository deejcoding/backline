'use client'

import { forwardRef, InputHTMLAttributes } from 'react'
import clsx from 'clsx'

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string
  error?: string
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className, label, error, id, ...props }, ref) => {
    const inputId = id || label?.toLowerCase().replace(/\s+/g, '-')

    return (
      <div className="flex flex-col gap-1">
        {label && (
          <label
            htmlFor={inputId}
            className="font-mono text-[10px] tracking-[0.15em] uppercase text-muted"
          >
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={inputId}
          className={clsx(
            'bg-transparent border border-dim text-ink px-3 py-2.5 font-mono text-sm outline-none transition-colors',
            'placeholder:text-muted',
            'focus:border-accent',
            error && 'border-signal-red',
            className
          )}
          {...props}
        />
        {error && (
          <span className="font-mono text-[10px] text-signal-red">{error}</span>
        )}
      </div>
    )
  }
)

Input.displayName = 'Input'
