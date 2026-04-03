---
description: ⚡⚡⚡ Scaffold a new fullstack project (Next.js + Hono backend)
argument-hint: "[project-name] [description] [--web] [--backend]"
---

Scaffold a new fullstack project based on these arguments:
<arguments>$ARGUMENTS</arguments>

## Parse Arguments

Extract from arguments:
- `project-name`: first non-flag word (kebab-case)
- `description`: text after project name (until flags)
- `--web`: scaffold Next.js frontend
- `--backend`: scaffold Node.js/Hono backend
- If neither --web nor --backend specified: scaffold BOTH

If project-name is missing, use `AskUserQuestion` to ask: "What is the project name? (kebab-case, e.g. my-saas-app)"

## Your Role

You are a senior fullstack architect. Scaffold a production-ready project based on **battle-tested patterns** from ListenWithMe (listenwithme.app). The generated code should:
- Run immediately with zero errors
- Have proper TypeScript types
- Include all env vars documented
- Apply all known bug fixes pre-emptively
- Be ready for blue-green EC2 deployment

Read the `fullstack-app` skill references before generating any code:
- `fullstack-app/references/backend-setup.md` — backend patterns
- `fullstack-app/references/frontend-setup.md` — frontend patterns
- `fullstack-app/references/deployment.md` — Docker + deploy scripts
- `fullstack-app/references/known-issues.md` — apply ALL fixes upfront

## Scaffold Steps

### Step 1: Project Structure
Create base directories:
- Backend: `./{project-name}-backend/`
- Frontend: `./{project-name}-web/`

### Step 2: Backend (if --backend or both)

Generate these files with project-specific naming (replace "myapp" with project-name):

```
{project-name}-backend/
├── src/
│   ├── app.ts                    # Hono HTTP server
│   ├── ws-server.ts              # Native ws WebSocket server
│   ├── lib/
│   │   ├── prisma.ts             # Prisma singleton
│   │   ├── redis.ts              # Redis (main + pub + sub clients)
│   │   ├── jwt.ts                # JWT sign/verify + JwtPayload interface
│   │   └── firebase-admin.ts    # LAZY INIT — critical!
│   └── middleware/
│       └── auth.ts               # JWT + tokenVersion middleware
├── prisma/
│   └── schema.prisma             # User model + base schema
├── Dockerfile
├── docker-compose.yml            # api-blue/green + ws-blue/green + postgres + redis
├── deploy.sh                     # Blue-green API deploy
├── deploy-ws.sh                  # Blue-green WS deploy (30s drain)
├── startup.sh                    # prisma migrate deploy + start API
├── startup-ws.sh                 # start WS server
├── .env.example
├── .gitignore
├── package.json
├── tsconfig.json
└── .github/
    └── workflows/
        ├── deploy.yml            # SSH deploy on push to main
        └── pr-check.yml          # TypeScript check on PRs
```

**Important customizations**:
- Replace `synctune`/`togetherfm` naming with project-name
- Update docker network name, upstream conf filenames, DB name
- Update `REPO_DIR` in deploy scripts to `/home/ubuntu/{project-name}`

### Step 3: Frontend (if --web or both)

Generate these files:

```
{project-name}-web/
├── src/
│   ├── app/
│   │   ├── layout.tsx            # Root layout (minimal, add providers)
│   │   ├── page.tsx              # Home page (placeholder)
│   │   └── api/
│   │       └── auth/
│   │           ├── token/
│   │           │   └── route.ts  # httpOnly cookie GET/POST/DELETE
│   │           └── google/
│   │               └── route.ts  # Firebase idToken proxy
│   ├── store/
│   │   └── authStore.ts          # Zustand: anonymous + email + Google
│   ├── lib/
│   │   └── firebase.ts           # HARDCODED FALLBACKS — critical!
│   └── components/
│       └── providers.tsx         # Client providers wrapper
├── next.config.mjs               # CSP with Firebase domains
├── tailwind.config.ts
├── .env.local.example
├── .gitignore
├── package.json
└── tsconfig.json
```

**Important**:
- In `firebase.ts`: hardcode actual placeholder values (user will replace). This prevents `auth/invalid-api-key` on Vercel.
- In `next.config.mjs` CSP: replace `YOUR_PROJECT_ID` with a placeholder comment.
- Cookie name: use `{project-name-camelCase}_token` (e.g. `mySaasApp_token`)

### Step 4: Print Setup Checklist

After generating all files, print this checklist:

```
## ✅ Project Scaffolded: {project-name}

### Next Steps

#### Firebase Setup
1. Create Firebase project at console.firebase.google.com
2. Enable Google Sign-In: Authentication → Sign-in method → Google
3. Add authorized domain: Authentication → Settings → Authorized domains
4. Get service account: Project Settings → Service Accounts → Generate new private key
5. Minify JSON: `cat service-account.json | python3 -m json.tool --compact`
6. Update firebase.ts with your actual project values

#### Backend (EC2)
```bash
# SSH to EC2
ssh ubuntu@YOUR_EC2_IP

# Clone repo
git clone git@github.com:YOUR_ORG/{project-name}-backend.git ~/{project-name}
cd ~/{project-name}

# Copy and fill .env
cp .env.example .env
nano .env  # Set all values

# First deploy
docker compose build && docker compose up -d api-blue ws-blue postgres redis

# Setup nginx upstream files
sudo bash -c 'echo "server 127.0.0.1:3001;" > /etc/nginx/{project-name}-upstream.conf'
sudo bash -c 'echo "server 127.0.0.1:3004;" > /etc/nginx/{project-name}-ws-upstream.conf'

# Allow nginx reload in deploy scripts
echo "ubuntu ALL=(ALL) NOPASSWD: /usr/sbin/nginx" | sudo tee /etc/sudoers.d/ubuntu-nginx
```

#### Frontend (Vercel)
```bash
npx vercel --prod
# Add env vars in Vercel dashboard:
# NEXT_PUBLIC_BACKEND_URL, NEXT_PUBLIC_FIREBASE_*, etc.
```

#### GitHub Secrets Needed
- EC2_HOST, EC2_USER, EC2_SSH_KEY
- DISCORD_WEBHOOK (optional)
```
