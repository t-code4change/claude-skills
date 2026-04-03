# Frontend Setup Guide

Stack: Next.js 14 App Router + Zustand + Tailwind + Firebase + Vercel

## Directory Structure

```
web/
├── src/
│   ├── app/
│   │   ├── layout.tsx          # Root layout with providers
│   │   ├── page.tsx            # Home page
│   │   └── api/
│   │       ├── auth/
│   │       │   ├── token/
│   │       │   │   └── route.ts   # GET/POST/DELETE httpOnly cookie
│   │       │   └── google/
│   │       │       └── route.ts   # Firebase idToken → backend
│   ├── store/
│   │   └── authStore.ts        # Zustand auth store
│   ├── lib/
│   │   ├── firebase.ts         # Firebase client (hardcoded fallbacks!)
│   │   └── socket.ts           # WebSocket client
│   └── components/
│       └── providers.tsx       # Client-side providers wrapper
├── next.config.mjs             # CSP headers (critical for Firebase)
├── tailwind.config.ts
└── package.json
```

## package.json (key deps)

```json
{
  "dependencies": {
    "firebase": "^11",
    "next": "14.2.x",
    "react": "^18",
    "react-dom": "^18",
    "zustand": "^5"
  },
  "devDependencies": {
    "@types/node": "^22",
    "@types/react": "^18",
    "tailwindcss": "^3",
    "typescript": "^5"
  }
}
```

## src/lib/firebase.ts

CRITICAL: Hardcode as fallbacks. Vercel doesn't inject NEXT_PUBLIC vars unless baked in at build time.
Firebase client config is PUBLIC — safe to hardcode.

```typescript
import { initializeApp, getApps } from 'firebase/app'

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || 'AIzaSy_YOUR_ACTUAL_KEY',
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || 'your-app.firebaseapp.com',
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || 'your-app',
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || 'your-app.firebasestorage.app',
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || '123456789',
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || '1:123:web:abc',
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID || 'G-XXXXX',
}

export const firebaseApp = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0]
```

## src/store/authStore.ts

```typescript
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface User {
  id: string
  displayName: string
  email?: string
  avatarUrl?: string
  isAnonymous: boolean
  tokenVersion: number
}

interface AuthState {
  user: User | null
  token: string | null
  isLoading: boolean
  setAuth: (user: User, token: string) => void
  logout: () => void
  loginAnonymous: () => Promise<void>
  loginWithGoogle: () => Promise<void>
  hydrate: () => Promise<void>
}

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || 'https://api.example.com'

export const useAuthStore = create<AuthState>()((set, get) => ({
  user: null,
  token: null,
  isLoading: true,

  setAuth: (user, token) => set({ user, token }),

  logout: async () => {
    await fetch('/api/auth/token', { method: 'DELETE' })
    localStorage.removeItem('app_user')
    set({ user: null, token: null })
  },

  loginAnonymous: async () => {
    const res = await fetch(`${BACKEND_URL}/api/auth/anonymous`, { method: 'POST' })
    if (!res.ok) throw new Error('Failed to create anonymous user')
    const { user, token } = await res.json()
    // Store token in httpOnly cookie
    await fetch('/api/auth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token }),
    })
    localStorage.setItem('app_user', JSON.stringify(user))
    set({ user, token })
  },

  loginWithGoogle: async () => {
    const { getAuth, GoogleAuthProvider, signInWithPopup } = await import('firebase/auth')
    const { firebaseApp } = await import('@/lib/firebase')

    const auth = getAuth(firebaseApp)
    const provider = new GoogleAuthProvider()

    try {
      const result = await signInWithPopup(auth, provider)
      const idToken = await result.user.getIdToken()
      const state = get()
      const anonToken = state.token && state.user?.isAnonymous ? state.token : undefined

      const res = await fetch('/api/auth/google', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken, anonToken }),
      })
      if (!res.ok) throw new Error('Google login failed')
      const { user, token } = await res.json()
      localStorage.setItem('app_user', JSON.stringify(user))
      set({ user, token })
    } catch (err: any) {
      if (err?.code === 'auth/popup-closed-by-user') return
      throw err
    }
  },

  hydrate: async () => {
    // 1. Try localStorage (fast, no network)
    const cached = localStorage.getItem('app_user')
    if (cached) {
      try { set({ user: JSON.parse(cached) }) } catch {}
    }

    // 2. Try httpOnly cookie (authoritative)
    try {
      const res = await fetch('/api/auth/token')
      if (res.ok) {
        const { token } = await res.json()
        if (token) {
          // Decode payload (not verification — server handles that)
          const payload = JSON.parse(atob(token.split('.')[1]))
          set({ token, isLoading: false })
          return
        }
      }
    } catch {}

    // 3. No session → create anonymous
    await get().loginAnonymous()
    set({ isLoading: false })
  },
}))
```

## src/app/api/auth/token/route.ts

```typescript
import { NextRequest, NextResponse } from 'next/server'

const COOKIE = 'app_token'
const COOKIE_OPTS = {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax' as const,
  maxAge: 60 * 60 * 24 * 30,
  path: '/',
}

// GET: read token from cookie (server-side)
export async function GET(req: NextRequest) {
  const token = req.cookies.get(COOKIE)?.value || null
  return NextResponse.json({ token })
}

// POST: set httpOnly cookie
export async function POST(req: NextRequest) {
  const { token } = await req.json()
  const res = NextResponse.json({ ok: true })
  res.cookies.set(COOKIE, token, COOKIE_OPTS)
  return res
}

// DELETE: logout
export async function DELETE() {
  const res = NextResponse.json({ ok: true })
  res.cookies.delete(COOKIE)
  return res
}
```

## src/app/api/auth/google/route.ts

```typescript
import { NextRequest, NextResponse } from 'next/server'

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || ''

export async function POST(req: NextRequest) {
  const body = await req.json()
  const res = await fetch(`${BACKEND_URL}/api/auth/google/firebase`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({ message: 'Login failed' }))
    return NextResponse.json(err, { status: res.status })
  }
  const data = await res.json()
  const response = NextResponse.json(data)
  response.cookies.set('app_token', data.token, {
    httpOnly: true, secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax', maxAge: 60 * 60 * 24 * 30, path: '/',
  })
  return response
}
```

## next.config.mjs

CRITICAL: CSP must include Firebase/Google domains or signInWithPopup will be blocked.

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  images: { remotePatterns: [{ protocol: 'https', hostname: '**' }] },
  headers: async () => [
    {
      source: '/(.*)',
      headers: [
        {
          key: 'Content-Security-Policy',
          value: [
            "default-src 'self'",
            "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://apis.google.com https://accounts.google.com",
            "frame-src https://accounts.google.com https://YOUR_PROJECT_ID.firebaseapp.com https://www.youtube.com",
            "connect-src 'self' wss: ws: https:",
            "img-src 'self' data: blob: https:",
            "style-src 'self' 'unsafe-inline'",
            "font-src 'self' data:",
          ].join('; '),
        },
        { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
      ],
    },
  ],
}

export default nextConfig
```

## .env.local.example

```bash
NEXT_PUBLIC_BACKEND_URL=http://localhost:3000
NEXT_PUBLIC_WS_URL=ws://localhost:3003
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=
NEXT_PUBLIC_FIREBASE_APP_ID=
NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID=
```
