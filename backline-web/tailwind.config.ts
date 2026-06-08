import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        ink: '#ffffff',
        paper: '#000000',
        muted: '#8a8a8a',
        dim: '#2a2a2a',
        soft: '#141414',
        accent: '#00c7be',
        'signal-green': '#30d158',
        'signal-yellow': '#ffcc00',
        'signal-red': '#ff3b30',
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Text', 'Segoe UI', 'Roboto', 'sans-serif'],
        display: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Display', 'sans-serif'],
        mono: ['ui-monospace', 'SF Mono', 'Menlo', 'Monaco', 'Cascadia Mono', 'monospace'],
      },
    },
  },
  plugins: [],
}
export default config
