# Claude Skills

Personal Claude Code skill collection — store once, use on any machine.

## Skills

| Skill | Description |
|-------|-------------|
| [ios-pro](./ios-pro/) | iOS development pro — SwiftUI, MVVM, XcodeGen, Fastlane, best practices 2024–2026 |
| [seo-optimization](./seo-optimization/) | SEO & web performance — Lighthouse 100, Core Web Vitals, accessibility, structured data |
| [strapi-server](./strapi-server/) | Strapi v5 TypeScript backend with AWS RDS PostgreSQL — fast, clean, zero errors |
| [backend-development](./backend-development/) | Backend systems — Node.js, REST/GraphQL APIs, auth, Docker, CI/CD, security (OWASP) |
| [nodejs-realtime-backend](./nodejs-realtime-backend/) | Node.js realtime — Socket.io, SSE, WebSocket, Redis pub/sub, BullMQ, horizontal scaling |

## Installation

### Clone & install all skills

```bash
git clone git@github.com:t-code4change/claude-skills.git ~/claude-skills
cd ~/claude-skills
chmod +x install.sh
./install.sh all
```

### Install a specific skill

```bash
./install.sh ios-pro
./install.sh strapi-server
```

Skills are installed to `~/.claude/skills/` — Claude Code picks them up automatically.

### Update to latest

```bash
cd ~/claude-skills
git pull
./install.sh all
```

## Adding a New Skill

1. Create a folder at repo root: `mkdir my-skill`
2. Add a `SKILL.md` (required by Claude) with frontmatter:
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

> README is updated manually after adding or updating skills — edit the Skills table above.

## Structure

```
claude-skills/
├── ios-pro/           # iOS development
│   └── README.md
├── seo-optimization/  # SEO & performance
│   ├── SKILL.md
│   └── references/
├── strapi-server/     # Strapi backend
│   ├── SKILL.md
│   └── references/
├── backend-development/
│   ├── SKILL.md
│   └── references/
├── install.sh         # Install script
└── README.md
```

## Requirements

- [Claude Code](https://claude.ai/download) installed
- macOS / Linux (install.sh is bash)
