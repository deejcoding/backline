'use client'

import { forwardRef, TextareaHTMLAttributes } from 'react'
import clsx from 'clsx'

interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string
  error?: string
}

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ className, label, error, id, ...props }, ref) => {
    const textareaId = id || label?.toLowerCase().replace(/\s+/g, '-')

    return (
      <div className="flex flex-col gap-1">
        {label && (
          <label
            htmlFor={textareaId}
            className="font-mono text-[10px] tracking-[0.15em] uppercase text-muted"
          >
            {label}
          </label>
        )}
        <textarea
          ref={ref}
          id={textareaId}
          className={clsx(
            'bg-transparent border border-dim text-ink px-3 py-2.5 font-mono text-sm outline-none transition-colors resize-y min-h-[100px]',
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

Textarea.displayName = 'Textarea'
