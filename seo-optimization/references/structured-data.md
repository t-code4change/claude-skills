# Structured Data (JSON-LD)

## Common Schemas
- Organization: name, url, logo, contactPoint, sameAs
- LocalBusiness: address, telephone, openingHours
- Product: name, description, brand, offers
- FAQPage: mainEntity with Question/Answer pairs
- BreadcrumbList: itemListElement with position, name, item

## Next.js Implementation
Use `<script type="application/ld+json">` with `dangerouslySetInnerHTML`.
Validate: https://search.google.com/test/rich-results
