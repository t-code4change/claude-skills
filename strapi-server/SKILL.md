---
name: strapi-server
description: Set up a Strapi v5 TypeScript backend with AWS RDS PostgreSQL — fast, clean, zero errors
triggers:
  - "tạo server với strapi"
  - "setup strapi"
  - "strapi backend"
  - "strapi server"
  - "khởi tạo strapi"
references:
  - references/setup.md
  - references/known-issues.md
  - references/patterns.md
scripts:
  - scripts/fix-compiler.js
---

# Strapi v5 Server Setup Skill

## Goal
Get a Strapi v5 TypeScript + PostgreSQL backend running correctly in one pass, applying all known fixes upfront.

## Critical Rules (ALWAYS apply these)

1. **Apply compiler patch FIRST** — before `npm run develop`, run `node scripts/fix-compiler.js` or apply patch manually. Without it, content types return `undefined` and server crashes.
2. **Use `auth: { scope: [] }` NOT `auth: true`** — Strapi v5 route config rejects boolean `true`.
3. **Add `: { env: any }` to all config files** — TypeScript strict mode breaks without it.
4. **Create `public/uploads/`** — Strapi crashes if missing.
5. **Never use raw SQL UUID migrations** — Strapi ORM expects integer IDs. Let Strapi manage schema.
6. **Always create `.dockerignore`** — without it, `node_modules` causes 879MB build context.

## Quick Start

```bash
# 1. Install deps
npm install

# 2. Create required directory
mkdir -p public/uploads

# 3. Apply compiler patch (CRITICAL)
node ~/.claude/skills/strapi-server/scripts/fix-compiler.js

# 4. Fix config files (add : { env: any } to all config/*.ts exports)
# See references/patterns.md

# 5. Set up .env with DB connection
# See references/setup.md for AWS RDS setup

# 6. Run
npm run develop
```

## When Something Breaks

See `references/known-issues.md` for all 6 known issues with exact fixes.
