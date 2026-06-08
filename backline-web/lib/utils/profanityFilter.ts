// Basic profanity filter for usernames
const BLOCKED_WORDS = [
  'admin', 'backline', 'moderator', 'support', 'official',
  // Add more blocked words as needed
]

export function containsProfanity(text: string): boolean {
  const lower = text.toLowerCase()
  return BLOCKED_WORDS.some(word => lower.includes(word))
}

export function isValidUsername(username: string): { valid: boolean; error?: string } {
  if (!username || username.length < 3) {
    return { valid: false, error: 'Username must be at least 3 characters' }
  }
  if (username.length > 20) {
    return { valid: false, error: 'Username must be 20 characters or less' }
  }
  if (!/^[a-zA-Z0-9_]+$/.test(username)) {
    return { valid: false, error: 'Username can only contain letters, numbers, and underscores' }
  }
  if (containsProfanity(username)) {
    return { valid: false, error: 'That username is not allowed' }
  }
  return { valid: true }
}
