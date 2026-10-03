# SKILL.md — jalalsaddi Portfolio / Résumé & Case Studies
## Antigravity Skill & Project Reference (Manifest Design Edition)

---

## 1. Project identity

- **Owner**: Jalal El Saddi
- **Live URL**: `https://jalalsaddi.de`
- **Framework**: Nuxt 2 (static generation via `nuxt generate`)
- **Repo**: `jalal_el_saddi_resume` (`main` branch)
- **Deploy target**: GitHub Pages (`gh-pages` branch)
- **Theme**: **"Manifest"** — editorial paper/ink design system with brass accents
- **Typography**: `IBM Plex Serif` (headings), `IBM Plex Sans` (body), `IBM Plex Mono` (stamps, dates, tags, code)
- **Languages**: Vue 2 SFCs, Scoped CSS, JSON (i18n), Markdown (case studies)
- **i18n**: `nuxt-i18n` — English (default, `/`) and German (`/de/` prefix)
- **Case Study content**: Markdown in `/static/content/en/` and `/static/content/de/`

---

## 2. File map — what lives where

| What you want to change | File(s) |
|---|---|
| Résumé header / Blog header (independent) | `components/resume/ResumeNav.vue` / `components/blog/BlogNav.vue` |
| Language + dark-mode controls (shared utility) | `components/shared/SiteControls.vue` |
| Page shells | `layouts/default.vue` (landing hub), `layouts/resume_layout.vue`, `layouts/blog_layout.vue` |
| Landing page hero & curated case studies | `pages/index.vue` |
| Résumé page layout & experience ledger | `pages/resume_index.vue` & `components/resume/ResumeView.vue` |
| Blog / Case Studies index page | `pages/blog.vue` |
| Individual Case Study markdown reader | `pages/projects/_slug.vue` & `components/blog/MarkdownPost.vue` |
| Breadcrumb navigation trail | `components/blog/Breadcrumbs.vue` (blog only) |
| Footer | `components/shared/SiteFooter.vue` |
| Manifest tokens + shared primitives | `assets/css/base.css` (global) |
| Résumé-only / Blog-only styles | `assets/css/resume.css` (`.resume-site`) / `assets/css/blog.css` (`.blog-site`) |
| Sitemap (hreflang) + robots.txt | `lib/sitemap.js` (used by `nuxt.config.js`) |
| EN<->DE article pairing | `lib/articlePairs.js` (pairs by cover `image`) |
| Favicon / touch-icon generator | `scripts/make-favicon.py` |
| Work history content (EN) | `locales/en.json` → `workExperiences.works[]` |
| Work history content (DE) | `locales/de.json` → `workExperiences.works[]` |
| Landing page copy (EN / DE) | `locales/en.json` & `locales/de.json` → `landing.*` |
| Personal info & tech stack | `locales/en.json` & `locales/de.json` → `personalInfo.*` |
| Case Study bodies (EN / DE) | `static/content/en/<slug>.md` & `static/content/de/<slug>.md` |
| Case Study registry | `locales/articles_en.json` & `locales/articles_de.json` |
| Nuxt build, SEO, sitemap, routing | `nuxt.config.js` |
| Domain preservation | `static/CNAME` (`jalalsaddi.de`) |
| Social card banner images | `static/resume_banner.jpg`, `static/blog_banner.jpg`, `static/profile.png` |

---

## 3. "Manifest" Color System & Typography

### Light mode (`:root` in `assets/css/resume.css`)
```css
--paper: #F7F5F0;
--paper-raised: #EDEBE6;
--ink: #1C1917;
--ink-soft: #57534E;
--rule: rgba(28, 25, 23, 0.14);
--brass: #B8860B;
--brass-subtle: rgba(184, 134, 11, 0.08);
--brass-hover: #996F09;

--font-serif: 'IBM Plex Serif', Georgia, 'Times New Roman', serif;
--font-sans: 'IBM Plex Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
--font-mono: 'IBM Plex Mono', Menlo, Monaco, Consolas, 'Liberation Mono', monospace;
```

### Dark mode (`.dark-mode` in `assets/css/resume.css`)
```css
--paper: #161614;
--paper-raised: #20201C;
--ink: #EDEDEB;
--ink-soft: #A8A29E;
--rule: rgba(237, 237, 235, 0.12);
--brass: #D4A017;
--brass-subtle: rgba(212, 160, 23, 0.14);
--brass-hover: #E5B228;
```

---

## 4. Résumé Architecture & Rules

1. **Kenntnisse Matrix**: Recruiter skills block at top of resume powered by `personalInfo.techStack`.
2. **Work Experience Ordering**:
   - Primary full-time employment entries (`type: "employment"`) **always appear first** in reverse-chronological order by `sortDate`.
   - Self-initiated/personal projects (`type: "personal"`) appear **after** employment entries.
   - Handled via comparator in `Resume.vue`'s `modernWorks` computed property.
3. **Bulleted Outcomes**: Each role has an array of concrete outcome-oriented bullets (`bullets: string[]`) underneath `summary`.
4. **Compressed Pre-2019 Legacy Block**: Soft Solutions (2009–2019) is kept as a compact archived block with an `ARCHIVED — ask if relevant` stamp.
5. **PDF Download / Print**: Header includes an interactive **Download PDF** button triggering `window.print()`, formatted cleanly by `@media print` rules.
6. **Closing Pointer**: Single footer pointer at the bottom directing readers to the Case Studies archive.

---

## 5. Blog & Case Studies Architecture

1. **Ledger Row Layout**: Tabular rows with `CASE 0X` badge, ISO date, title, abstract, tags, and category.
2. **Independent from the résumé**: no `jobEra` field, no "Belongs to" badge, no links to `/resume_index`. Only the landing page links to both sections.
3. **Category & Tag Filters**: Dynamic filtering by category ("All", "Articles", "Projects") and multi-tag chips.

---

## 6. Build & Deploy Commands

```bash
npm run dev         # Development server
npm run generate    # Static generation to dist/ with sitemap.xml & robots.txt
npm run deploy      # Build and push dist/ to gh-pages branch
```


---

## 7. Section independence (résumé / blog)

- Three layouts, three headers: landing = `default`, résumé = `resume_layout`, blog = `blog_layout`. Each header is its own component but carries the same three links (Home, Résumé, Case Studies) so visitors can move freely; there is no structural coupling (no shared metadata, no cross-links inside content).
- `base.css` holds tokens and primitives only. Section styles are namespaced (`.resume-site`, `.blog-site`) and loaded by their own layout; the landing page keeps its ledger styles in `pages/index.vue`.
- Content may still talk about the same work; there is just no structural link (no shared metadata field, no shared nav item).

## 8. Sitemap

`static/sitemap.xsl` only makes sitemap.xml readable in browsers (crawlers ignore it). `lib/sitemap.js` emits one `<url>` per language version; every entry lists all `xhtml:link rel="alternate"` variants (en, de, x-default -> default locale). Articles are paired by identical cover `image` in both registries because EN/DE slugs differ for some posts. Keep `DEFAULT_LOCALE` in `lib/sitemap.js` equal to nuxt-i18n `defaultLocale`. Bump `STATIC_PAGES[].lastmod` when a static page's content changes.

## 9. Footer "Last updated"

`components/shared/SiteFooter.vue` shows the **deploy time**, not the visitor's time: `BUILD_TIME` is set once in `nuxt.config.js` (`env`) when `nuxt generate` runs and is formatted in the `Europe/Berlin` time zone. Never use `new Date()` for it in the component.
