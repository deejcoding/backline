import { SignUpForm } from '@/components/auth'

export default function SignUpPage() {
  return (
    <div className="min-h-[calc(100vh-65px)] flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="font-mono text-2xl font-bold uppercase tracking-tight mb-2">
            Join Backline
          </h1>
          <p className="font-mono text-sm text-muted">
            Create your account to connect with NYC musicians
          </p>
        </div>

        <SignUpForm />
      </div>
    </div>
  )
}
