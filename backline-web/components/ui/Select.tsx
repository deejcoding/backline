'use client'

import { forwardRef, SelectHTMLAttributes } from 'react'
import clsx from 'clsx'
import { ChevronDown } from 'lucide-react'

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string
  error?: string
  options: { value: string; label: string }[]
}

export const Select = forwardRef<HTMLSelectElement, SelectProps>(
  ({ className, label, error, id, options, ...props }, ref) => {
    const selectId = id || label?.toLowerCase().replace(/\s+/g, '-')

    return (
      <div className="flex flex-col gap-1">
        {label && (
          <label
            htmlFor={selectId}
            className="font-mono text-[10px] tracking-[0.15em] uppercase text-muted"
          >
            {label}
          </label>
        )}
        <div className="relative">
          <select
            ref={ref}
            id={selectId}
            className={clsx(
              'w-full bg-transparent border border-dim text-ink px-3 py-2.5 font-mono text-sm outline-none transition-colors appearance-none cursor-pointer',
              'focus:border-accent',
              error && 'border-signal-red',
              className
            )}
            {...props}
          >
            {options.map((option) => (
              <option key={option.value} value={option.value} className="bg-soft">
                {option.label}
              </option>
            ))}
          </select>
          <ChevronDown
            size={16}
            className="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none text-muted"
          />
        </div>
        {error && (
          <span className="font-mono text-[10px] text-signal-red">{error}</span>
        )}
      </div>
    )
  }
)

Select.displayName = 'Select'
