# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```
npm run dev      # Start dev server at localhost:4321
npm run build    # Build to ./dist/
npm run preview  # Preview production build locally
npm run astro -- check  # Type-check the project
```

No test suite or linter is configured.

## Architecture

This is an **Astro 6** blog starter template with TypeScript, Markdown/MDX content collections, and built-in RSS + sitemap support.

### Routing (file-based)

- `src/pages/index.astro` → `/` (home page)
- `src/pages/blog/index.astro` → `/blog` (post listing)
- `src/pages/blog/[...slug].astro` → `/blog/:slug` (individual post, uses `getStaticPaths` for SSG)
- `src/pages/about.astro` → `/about` (uses BlogPost layout)
- `src/pages/rss.xml.js` → `/rss.xml` (RSS feed endpoint)

### Content

Blog posts live in `src/content/blog/` as `.md` or `.mdx` files. The collection schema is defined in `src/content.config.ts` using `astro:content`. Required frontmatter: `title` (string), `description` (string), `pubDate` (date). Optional: `updatedDate` (date), `heroImage` (image).

Posts are loaded via `getCollection('blog')` and rendered via `render(post)` from `astro:content`.

### Layouts & Components

- **`src/layouts/BlogPost.astro`** — The shared layout for blog posts and the about page. Receives `title`, `description`, `pubDate`, `updatedDate?`, `heroImage?` as props and renders content via `<slot />`.
- **`src/components/BaseHead.astro`** — `<head>` metadata (charset, viewport, OG tags, Twitter card, canonical URL, favicon, font preloading). Uses `Astro.site` and `Astro.url`.
- **`src/components/Header.astro`** — Site header with nav links (Home, Blog, About) plus social icon links. Wraps links in `HeaderLink.astro` for active-state styling.
- **`src/components/HeaderLink.astro`** — Single nav link with active-state detection via `Astro.url.pathname` matching.
- **`src/components/Footer.astro`** — Page footer with copyright year and social links.
- **`src/components/FormattedDate.astro`** — Renders a `<time>` element from a `Date` prop.

### Styles & Fonts

- **`src/styles/global.css`** — Global styles with CSS custom properties for theming (colors in `--accent`, `--black`, `--gray`, etc.). Imported by `BaseHead.astro` so it's included on every page.
- **Fonts** — Atkinson Hyperlegible loaded locally via Astro's `fontProviders.local()` in `astro.config.mjs`. Configured as CSS variable `--font-atkinson`.

### Site Config

Global constants (`SITE_TITLE`, `SITE_DESCRIPTION`) in `src/consts.ts`. The `site` URL in `astro.config.mjs` should be changed from `https://example.com` to the production domain.

## Changelog — 2026-05-25 Home Page Redesign

### Summary
Redesigned the home page with a card-based two-column layout, new visual identity, and background image.

### Site branding
- `src/consts.ts`: `SITE_TITLE` → `"KaitoBlog"`, `SITE_DESCRIPTION` → Chinese description
- `src/components/Footer.astro`: Simplified to `© YYYY kaito.`

### Home page (`src/pages/index.astro`)
- **Layout**: 1/3 + 2/3 flex split. Left: avatar card (sticky). Right: blog post card.
- **Profile card**: Circular avatar, name "kaito", Chinese bio, external links (GitHub / Twitter / Email).
- **Post card**: Latest 5 posts sorted by `pubDate` desc, each with title/date/description, plus "查看全部文章 →" link.
- **Background**: `public/bg-pattern.svg` (gradient + grid + wavy lines + radial glows) via `.page-wrapper::before { position: fixed; z-index: -1; }`.
- **Card styling**: All modules use `background: rgba(255,255,255,1); border-radius: 20px; box-shadow: 0 2px 12px rgba(var(--black), 0.04)`. No transparency on cards — background image only shows in gaps and sides.
- **Global `main` override**: Scoped `main { width: 100%; max-width: 1140px; padding: 0; background: transparent }` to bypass `global.css` 720px limit.

### Header (`src/components/Header.astro`)
- Added search button (SVG magnifier) top-right.
- Navbar redesigned as a card matching the profile/post-feed below: `border-radius: 20px`, white background, same `max-width: 1140px` and `box-shadow`.
- `header` element kept `background: transparent` so background image shows on sides.
- `.nav-inner` uses `max-width: 1140px; margin: 0 auto; padding: 0.6em 2em` to align with hero cards below.
- `header` has `padding: 0` — navbar sits flush at the top of the viewport.

### Background image
- `public/bg-pattern.svg` — static SVG with gradient fills, subtle grid lines, wavy curves, and radial glow spots.
- Applied via fixed pseudo-element on `.page-wrapper`, sits behind all content.

### Alignment constraints
All three horizontal modules share identical dimensions for left-edge alignment:
| Module | max-width | padding | border-radius |
|---|---|---|---|
| `.nav-inner` | 1140px | 0.6em 2em | 20px |
| `.profile` (hero child) | 33.333% of hero | 2em | 20px |
| `.post-feed` (hero child) | 66.666% of hero | 2em | 20px |
| `.hero` | 1140px | 0 | — |

The gap between `.profile` and `.post-feed` (`gap: 2em` on `.hero`) shows the background image.

