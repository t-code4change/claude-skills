# Claude Skills

Personal Claude Code skill collection — store once, use on any machine.

## `init-claude` CLI

Scaffold a complete `.claude/` project setup (skills, hooks, commands, agents) in one command.

### Install (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/t-code4change/claude-skills/main/install-cli.sh | bash
```

Then open a new terminal and run:

```bash
cd your-project
init-claude
```

### Update

```bash
curl -fsSL https://raw.githubusercontent.com/t-code4change/claude-skills/main/install-cli.sh | bash
```

---

## Skills

| Skill | Description |
|-------|-------------|
| [firebase](./firebase/) | Firebase Auth — Google Sign-In (popup) with Next.js + Node.js/Hono. Lazy init, CSP, docker-compose env, all known bugs documented. |
| [ios-pro](./ios-pro/) | iOS development pro — SwiftUI, MVVM, XcodeGen, Fastlane, best practices 2024–2026 |
| [seo-optimization](./seo-optimization/) | SEO & web performance — Lighthouse 100, Core Web Vitals, accessibility, structured data |
| [strapi-server](./strapi-server/) | Strapi v5 TypeScript backend with AWS RDS PostgreSQL — fast, clean, zero errors |
| [backend-development](./backend-development/) | Backend systems — Node.js, REST/GraphQL APIs, auth, Docker, CI/CD, security (OWASP) |
| [nodejs-realtime-backend](./nodejs-realtime-backend/) | Node.js realtime — Socket.io, SSE, WebSocket, Redis pub/sub, BullMQ, horizontal scaling |

## Install Skills

### One-liner (install all to `~/.claude/skills/`)

```bash
git clone git@github.com:t-code4change/claude-skills.git ~/claude-skills
cd ~/claude-skills && chmod +x install.sh && ./install.sh all
```

### Install a specific skill

```bash
./install.sh firebase
./install.sh ios-pro
./install.sh strapi-server
```

### Update to latest

```bash
cd ~/claude-skills && git pull && ./install.sh all
```

Skills are installed to `~/.claude/skills/` — Claude Code picks them up automatically.

---

## Adding a New Skill

1. Create folder: `mkdir my-skill`
2. Add `SKILL.md` with frontmatter:
   ```yaml
   ---
   name: my-skill
   description: When Claude should use this skill
   ---
   # My Skill
   Instructions here...
   ```
3. Install locally: `./install.sh my-skill`
4. Push: `git add . && git commit -m "feat: add my-skill" && git push`

---

## Structure

```
claude-skills/
├── firebase/               # Firebase Auth (Google Sign-In)
│   ├── SKILL.md
│   └── references/
│       ├── integration-guide.md
│       └── known-issues.md
├── ios-pro/                # iOS SwiftUI development
├── seo-optimization/       # SEO & Lighthouse
│   ├── SKILL.md
│   └── references/
├── strapi-server/          # Strapi v5 + PostgreSQL
│   ├── SKILL.md
│   └── references/
├── backend-development/    # Node.js backend patterns
│   ├── SKILL.md
│   └── references/
├── bin/
│   └── init-claude         # CLI script
├── install.sh              # Skills installer
├── install-cli.sh          # CLI installer (one-liner)
└── README.md
```

## Requirements

- [Claude Code](https://claude.ai/download) installed
- macOS / Linux
