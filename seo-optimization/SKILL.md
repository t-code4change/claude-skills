---
name: seo-optimization
description: Optimize website performance, accessibility, SEO, and best practices targeting Lighthouse 100 scores. This skill should be used when auditing PageSpeed/Lighthouse scores, fixing WCAG color contrast issues, resolving form accessibility problems, making links crawlable, fixing canonical URLs, validating robots.txt/sitemap.xml, optimizing fonts and images, implementing lazy loading, adding JSON-LD structured data, or improving Core Web Vitals (LCP, CLS, FID/INP).
version: 1.0.0
---

# SEO & Website Optimization Skill

Audit and fix web performance, accessibility, SEO, and best practices using Lighthouse CLI.

## Workflow

### 1. Audit with Lighthouse CLI
```bash
npx lighthouse <URL> --output=json --output-path=./lighthouse-report.json --chrome-flags="--headless --no-sandbox"
npx lighthouse <URL> --preset=desktop --output=json --output-path=./lighthouse-desktop.json --chrome-flags="--headless --no-sandbox"
```

Parse scores: `jq '.categories | to_entries[] | {(.key): .value.score}' lighthouse-report.json`
Parse failures: `jq '[.audits | to_entries[] | select(.value.score != null and .value.score < 1)] | sort_by(.value.score) | .[:20] | .[] | {id: .key, score: .value.score, title: .value.title}' lighthouse-report.json`

### 2. Fix Issues by Category
- **Accessibility** → `references/accessibility.md` (contrast, labels, headings, ARIA)
- **SEO** → `references/seo-technical.md` (canonical, robots, crawlable links, meta)
- **Performance** → `references/performance.md` (fonts, images, lazy loading, caching)
- **Structured Data** → `references/structured-data.md` (JSON-LD schemas)

### 3. Verify & Deploy
After fixes: rebuild → redeploy → re-run Lighthouse → confirm scores reach target.
Use parallel agents for independent fix categories.

## Quick Reference: Common Lighthouse Failures

| Audit ID | Category | Fix Reference |
|---|---|---|
| color-contrast | A11y | `references/accessibility.md` |
| label | A11y | `references/accessibility.md` |
| crawlable-anchors | SEO | `references/seo-technical.md` |
| link-text | SEO | `references/seo-technical.md` |
| canonical | SEO | `references/seo-technical.md` |
| largest-contentful-paint | Perf | `references/performance.md` |
