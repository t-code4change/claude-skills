# Firebase Google Login — Full Integration Guide

Stack: **Next.js (App Router)** + **Node.js/Hono backend** + **Prisma/PostgreSQL**

---

## Backend

### 1. Install

```bash
npm install firebase-admin
```

### 2. Firebase Admin — Lazy Init (`src/lib/firebase-admin.ts`)

```typescript
import { initializeApp, getApps, cert } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'

let _initialized = false

function ensureInit() {
  if (_initialized) return
  const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT
  if (!serviceAccount) throw new Error('FIREBASE_SERVICE_ACCOUNT not set')
  if (getApps().length === 0) {
    initializeApp({ credential: cert(JSON.parse(serviceAccount)) })
  }
  _initialized = true
}

export const firebaseAuth = {
  verifyIdToken: (idToken: string) => {
    ensureInit()
    return getAuth().verifyIdToken(idToken)
  },
}
```

### 3. Auth Endpoint (`POST /api/auth/google/firebase`)

```typescript
// In app.ts — MUST be in publicPaths (no auth middleware)
app.post('/api/auth/google/firebase', async (c) => {
  const { idToken, anonToken } = await c.req.json()

  // Verify Firebase token
  const decoded = await firebaseAuth.verifyIdToken(idToken)
  const { email, name, picture, uid } = decoded

  // Find or create user in DB
  const user = await googleLoginOrCreate({
    googleId: uid,
    email: email!,
    displayName: name || email!.split('@')[0],
    avatarUrl: picture,
    // If anonToken provided, merge anonymous user's data
    anonToken,
  })

  // Generate your app's JWT
  const token = signJwt({ userId: user.id, tokenVersion: user.tokenVersion })

  return c.json({ user, token })
})
```

Add to publicPaths array:
```typescript
const publicPaths = [
  '/api/auth/login',
  '/api/auth/register',
  '/api/auth/google/firebase',  // ← add this
]
```

### 4. `docker-compose.yml`

```yaml
services:
  app:
    environment:
      - NODE_ENV=${NODE_ENV}
      - DATABASE_URL=${DATABASE_URL}
      - JWT_SECRET=${JWT_SECRET}
      - FIREBASE_SERVICE_ACCOUNT=${FIREBASE_SERVICE_ACCOUNT}  # ← add this
```

---

## Frontend (Next.js)

### 1. Firebase Client Config (`src/lib/firebase.ts`)

```typescript
import { initializeApp, getApps } from 'firebase/app'

// Hardcode as fallbacks — safe, this is public client config
const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "AIzaSy_YOUR_KEY",
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || "your-app.firebaseapp.com",
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "your-app",
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || "your-app.firebasestorage.app",
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || "123456789",
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "1:123:web:abc",
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID || "G-XXXXX",
}

export const firebaseApp = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0]
```

### 2. Auth Store — `loginWithGoogle`

```typescript
// In Zustand store or auth context
loginWithGoogle: async () => {
  const { getAuth, GoogleAuthProvider, signInWithPopup } = await import('firebase/auth')
  const { firebaseApp } = await import('@/lib/firebase')

  const auth = getAuth(firebaseApp)
  const provider = new GoogleAuthProvider()

  try {
    const result = await signInWithPopup(auth, provider)
    const idToken = await result.user.getIdToken()

    // Include anon token if current user is anonymous (for data merge)
    const anonToken = state.token && state.user?.isAnonymous ? state.token : undefined

    const res = await fetch('/api/auth/google', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken, anonToken }),
    })

    if (!res.ok) throw new Error('Login failed')
    const { user, token } = await res.json()

    // Persist to store
    set({ user, token })
    localStorage.setItem('token', token)
  } catch (err: any) {
    // Silently ignore popup-closed-by-user
    if (err?.code === 'auth/popup-closed-by-user') return
    throw err
  }
}
```

### 3. Next.js Proxy Route (`src/app/api/auth/google/route.ts`)

```typescript
import { NextRequest, NextResponse } from 'next/server'

const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || 'https://your-backend.com'

export async function POST(req: NextRequest) {
  const body = await req.json()

  const res = await fetch(`${BACKEND_URL}/api/auth/google/firebase`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })

  if (!res.ok) {
    const error = await res.json().catch(() => ({ message: 'Login failed' }))
    return NextResponse.json(error, { status: res.status })
  }

  const data = await res.json()

  // Optionally set httpOnly cookie
  const response = NextResponse.json(data)
  response.cookies.set('auth-token', data.token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 30, // 30 days
  })

  return response
}
```

### 4. CSP Headers (`next.config.mjs`)

```javascript
{
  key: "Content-Security-Policy",
  value: [
    "default-src 'self'",
    // Add Google/Firebase domains:
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://apis.google.com https://accounts.google.com https://www.googletagmanager.com",
    "frame-src https://accounts.google.com https://YOUR_PROJECT_ID.firebaseapp.com https://www.youtube.com",
    "connect-src 'self' wss: ws: https:",
    "img-src 'self' data: blob: https:",
    "style-src 'self' 'unsafe-inline'",
    "font-src 'self' data:",
  ].join("; "),
}
```

### 5. Login Button Component

```tsx
function GoogleLoginButton() {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const loginWithGoogle = useAuthStore(s => s.loginWithGoogle)

  const handleClick = async () => {
    setLoading(true)
    setError(null)
    try {
      await loginWithGoogle()
    } catch (err: any) {
      if (err?.code !== 'auth/popup-closed-by-user') {
        setError('Đăng nhập thất bại. Vui lòng thử lại.')
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <button onClick={handleClick} disabled={loading}>
      {loading ? <Spinner /> : <GoogleIcon />}
      {loading ? 'Đang đăng nhập...' : 'Tiếp tục với Google'}
    </button>
  )
}
```

---

## Environment Variables

### Backend (EC2 `.env`)
```bash
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"your-app","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-...@your-app.iam.gserviceaccount.com","client_id":"...","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token"}
```

> Tip: minify the JSON first: `cat service-account.json | jq -c . | pbcopy`

### Frontend (Vercel)
```
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSy...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your-app.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your-app
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your-app.firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
NEXT_PUBLIC_FIREBASE_APP_ID=1:123:web:abc
NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID=G-XXXXX
```

---

## Firebase Console Checklist

1. Project Settings → Service Accounts → Generate new private key → download JSON
2. Authentication → Sign-in method → Google → Enable
3. Authentication → Settings → Authorized domains → Add your production domain
4. Get values for `NEXT_PUBLIC_FIREBASE_*` from Project Settings → General → Your apps
