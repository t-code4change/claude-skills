# Accessibility Fixes (WCAG AA)

## Color Contrast
WCAG AA: **4.5:1** normal text, **3:1** large text (>=18.66px bold or >=24px).

| Original | Replacement | Ratio on white | Context |
|---|---|---|---|
| `#EC1E24` | `#E31C22` | 4.73:1 | Brand red on white bg |
| `#888` | `#767676` | 4.54:1 | Placeholder on white bg |
| `#888` | `#B0B0B0` | 4.65:1 on `#3D3D3D` | Light text on dark bg |

Fix: grep for color hex codes, replace with compliant alternatives. Check both 3-digit and 6-digit forms.

## Form Labels
Every input needs label association:
- Explicit: `<label htmlFor="id">` + `<input id="id">`
- Implicit: `<label><input/></label>`
- ARIA: `<input aria-label="description">`

## Heading Order
No skipping levels: h1 -> h2 -> h3. One h1 per page.

## Select Element Labels
Every `<select>` needs `<label htmlFor>`, `aria-label`, or `aria-labelledby`.
