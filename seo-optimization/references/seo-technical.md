# Technical SEO Fixes

## Canonical URL
Must match accessed domain. Next.js: set `metadataBase` in layout metadata.
Common issue: env var trailing newline. Use `printf` not `echo` for CLI env var setting.

## robots.txt
Next.js: `src/app/robots.ts` with rules + sitemap URL from env var.

## Crawlable Links
Must be `<a href="...">`. Invalid: `<button>` wrapping `<a>`, `<a>` without href.
Fix: `<div role="button">` + proper `<a href>`.

## Descriptive Link Text
"Learn more" fails. Fix: "Learn more about [topic]" or use `aria-label`.

## Meta Tags
- `<title>`: 50-60 chars, `<meta description>`: 150-160 chars
- `<meta viewport>`: width=device-width, initial-scale=1
