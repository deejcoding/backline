'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { MapPin, Music, Camera, FileText, ChevronRight } from 'lucide-react'
import { useAuthStore } from '@/lib/stores/authStore'
import { Button, Input, Textarea, Avatar } from '@/components/ui'
import clsx from 'clsx'

const NEIGHBORHOODS = [
  'Bushwick', 'Williamsburg', 'Greenpoint', 'Bed-Stuy', 'Crown Heights',
  'Park Slope', 'Gowanus', 'Sunset Park', 'Bay Ridge', 'Flatbush',
  'East Village', 'Lower East Side', 'Chinatown', 'SoHo', 'Tribeca',
  'Hell\'s Kitchen', 'Harlem', 'Washington Heights', 'Astoria', 'Long Island City',
  'Jackson Heights', 'Flushing', 'Bronx', 'Staten Island',
]

const ROLES = [
  'Drums', 'Guitar', 'Bass', 'Vocals', 'Keys', 'Synth',
  'DJ', 'Producer', 'Recording Engineer', 'Mixing Engineer',
  'Live Sound', 'Photography', 'Videography', 'Graphic Design',
  'Booking', 'Management', 'Saxophone', 'Trumpet', 'Violin',
]

const GENRES = [
  'Rock', 'Indie', 'Punk', 'Metal', 'Jazz', 'Hip-Hop',
  'Electronic', 'House', 'Techno', 'Ambient', 'Folk',
  'Country', 'R&B', 'Soul', 'Funk', 'Pop', 'Classical',
  'Experimental', 'Noise', 'Shoegaze', 'Post-Punk',
]

const steps = [
  { id: 0, title: 'Neighborhood', icon: MapPin },
  { id: 1, title: 'Roles', icon: Music },
  { id: 2, title: 'Photo', icon: Camera },
  { id: 3, title: 'Bio', icon: FileText },
]

export default function OnboardingPage() {
  const router = useRouter()
  const { user, profile, needsOnboarding, onboardingStep, updateNeighborhood, updateRoles, updateGenres, uploadProfilePhoto, updateBio, completeOnboarding } = useAuthStore()

  const [step, setStep] = useState(onboardingStep)
  const [neighborhood, setNeighborhood] = useState(profile?.neighborhood || '')
  const [selectedRoles, setSelectedRoles] = useState<string[]>(profile?.roles || [])
  const [selectedGenres, setSelectedGenres] = useState<string[]>(profile?.genres || [])
  const [bio, setBio] = useState(profile?.bio || '')
  const [photoFile, setPhotoFile] = useState<File | null>(null)
  const [photoPreview, setPhotoPreview] = useState<string | null>(profile?.profilePhotoURL || null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const fileInputRef = useRef<HTMLInputElement>(null)

  if (!user) {
    router.push('/login')
    return null
  }

  if (!needsOnboarding) {
    router.push('/')
    return null
  }

  const toggleRole = (role: string) => {
    setSelectedRoles((prev) =>
      prev.includes(role) ? prev.filter((r) => r !== role) : [...prev, role]
    )
  }

  const toggleGenre = (genre: string) => {
    setSelectedGenres((prev) =>
      prev.includes(genre) ? prev.filter((g) => g !== genre) : [...prev, genre]
    )
  }

  const handlePhotoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      setPhotoFile(file)
      setPhotoPreview(URL.createObjectURL(file))
    }
  }

  const handleNext = async () => {
    setIsSubmitting(true)

    try {
      if (step === 0 && neighborhood) {
        await updateNeighborhood(neighborhood)
      } else if (step === 1) {
        await updateRoles(selectedRoles)
        await updateGenres(selectedGenres)
      } else if (step === 2 && photoFile) {
        await uploadProfilePhoto(photoFile)
      } else if (step === 3) {
        await updateBio(bio)
      }

      if (step < 3) {
        setStep(step + 1)
      } else {
        await completeOnboarding()
        router.push('/')
      }
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleSkip = () => {
    if (step < 3) {
      setStep(step + 1)
    } else {
      completeOnboarding()
      router.push('/')
    }
  }

  return (
    <div className="min-h-[calc(100vh-65px)] flex flex-col items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Progress */}
        <div className="flex items-center justify-center gap-2 mb-8">
          {steps.map((s, idx) => (
            <div
              key={s.id}
              className={clsx(
                'w-2 h-2 rounded-full transition-colors',
                idx <= step ? 'bg-accent' : 'bg-dim'
              )}
            />
          ))}
        </div>

        {/* Step Content */}
        {step === 0 && (
          <div className="text-center">
            <MapPin size={32} className="mx-auto text-accent mb-4" />
            <h1 className="font-mono text-xl font-bold uppercase tracking-tight mb-2">
              Where are you based?
            </h1>
            <p className="font-mono text-sm text-muted mb-6">
              This helps connect you with local musicians
            </p>

            <div className="flex flex-wrap gap-2 justify-center mb-6">
              {NEIGHBORHOODS.map((n) => (
                <button
                  key={n}
                  onClick={() => setNeighborhood(n)}
                  className={clsx(
                    'px-3 py-1.5 font-mono text-xs uppercase tracking-wider border transition-colors',
                    neighborhood === n
                      ? 'bg-accent text-paper border-accent'
                      : 'bg-transparent text-muted border-dim hover:border-muted'
                  )}
                >
                  {n}
                </button>
              ))}
            </div>
          </div>
        )}

        {step === 1 && (
          <div className="text-center">
            <Music size={32} className="mx-auto text-accent mb-4" />
            <h1 className="font-mono text-xl font-bold uppercase tracking-tight mb-2">
              What do you do?
            </h1>
            <p className="font-mono text-sm text-muted mb-6">
              Select your roles and genres
            </p>

            <div className="mb-6">
              <p className="font-mono text-xs text-muted uppercase tracking-wider mb-2">Roles</p>
              <div className="flex flex-wrap gap-2 justify-center">
                {ROLES.map((role) => (
                  <button
                    key={role}
                    onClick={() => toggleRole(role)}
                    className={clsx(
                      'px-3 py-1.5 font-mono text-xs uppercase tracking-wider border transition-colors',
                      selectedRoles.includes(role)
                        ? 'bg-accent text-paper border-accent'
                        : 'bg-transparent text-muted border-dim hover:border-muted'
                    )}
                  >
                    {role}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <p className="font-mono text-xs text-muted uppercase tracking-wider mb-2">Genres</p>
              <div className="flex flex-wrap gap-2 justify-center">
                {GENRES.map((genre) => (
                  <button
                    key={genre}
                    onClick={() => toggleGenre(genre)}
                    className={clsx(
                      'px-3 py-1.5 font-mono text-xs uppercase tracking-wider border transition-colors',
                      selectedGenres.includes(genre)
                        ? 'bg-accent text-paper border-accent'
                        : 'bg-transparent text-muted border-dim hover:border-muted'
                    )}
                  >
                    {genre}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {step === 2 && (
          <div className="text-center">
            <Camera size={32} className="mx-auto text-accent mb-4" />
            <h1 className="font-mono text-xl font-bold uppercase tracking-tight mb-2">
              Add a photo
            </h1>
            <p className="font-mono text-sm text-muted mb-6">
              Help others recognize you
            </p>

            <div className="flex flex-col items-center gap-4">
              <button
                onClick={() => fileInputRef.current?.click()}
                className="relative"
              >
                <Avatar src={photoPreview} size="xl" />
                <div className="absolute inset-0 rounded-full bg-paper/50 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                  <Camera size={24} className="text-ink" />
                </div>
              </button>

              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handlePhotoChange}
                className="hidden"
              />

              <Button
                variant="outline"
                size="sm"
                onClick={() => fileInputRef.current?.click()}
              >
                {photoPreview ? 'Change Photo' : 'Upload Photo'}
              </Button>
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="text-center">
            <FileText size={32} className="mx-auto text-accent mb-4" />
            <h1 className="font-mono text-xl font-bold uppercase tracking-tight mb-2">
              Tell us about yourself
            </h1>
            <p className="font-mono text-sm text-muted mb-6">
              A short bio helps others get to know you
            </p>

            <Textarea
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              placeholder="I'm a drummer based in Bushwick, playing in a post-punk band..."
              rows={4}
              maxLength={500}
            />
            <p className="font-mono text-[10px] text-muted mt-1 text-right">
              {bio.length}/500
            </p>
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-3 mt-8">
          <Button
            variant="ghost"
            onClick={handleSkip}
            disabled={isSubmitting}
            className="flex-1"
          >
            Skip
          </Button>
          <Button
            onClick={handleNext}
            isLoading={isSubmitting}
            className="flex-1 gap-1.5"
          >
            {step === 3 ? 'Finish' : 'Next'}
            <ChevronRight size={16} />
          </Button>
        </div>
      </div>
    </div>
  )
}
