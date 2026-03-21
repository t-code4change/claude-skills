# Performance Optimization

## Fonts
Self-host with next/font. Use `display: swap`. Limit weights to actual usage.

## Images
Next.js Image: `sizes` prop for fill images. `priority` for above-fold. Default lazy loading.

## LCP (< 2.5s)
Preload LCP image. Use `priority` on hero images. Minimize TTFB.

## CLS (< 0.1)
Set width/height on images. Reserve space for dynamic content. Use `font-display: swap`.

## Script Loading
Next.js Script: `afterInteractive` for analytics, `lazyOnload` for low-priority.

## Caching
Static assets: `Cache-Control: public, max-age=31536000, immutable`.
