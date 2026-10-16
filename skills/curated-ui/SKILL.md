---
name: curated-ui
description: Prefer mature, production-oriented UI components, interaction patterns, effects, icons, templates, and design references from the user's curated sources when building or reviewing frontend interfaces. Search the local catalogue first, then fetch official documentation or free source on demand; exclude paid or Pro material.
metadata:
  short-description: Use curated UI libraries before inventing UI
---

# Curated UI

Use this skill for frontend implementation, UI redesign, interaction design, component selection, and UI review. Its purpose is to reduce generic AI-looking interfaces and fragile one-off interactions by starting from proven entries in the user's curated sources.

The source list and current catalogue are in [data/sources.json](data/sources.json) and [data/catalog.json](data/catalog.json). The catalogue is a discovery index, not a vendored copy of third-party code. Read [references/sources.md](references/sources.md) when source boundaries or coverage matter. Read [references/maintenance.md](references/maintenance.md) when refreshing the catalogue or adding a source.

## Workflow

1. Inspect the existing project before choosing a library: framework, styling system, package manager, routing, component aliases, motion system, SSR/client boundaries, accessibility conventions, and current dependencies.
2. Translate the request into a UI job: loading, search, select, navigation, dialog, table, chart, upload, chat, AI trace, text effect, background, icon, template, or an inspiration pattern. Include the state model and constraints such as keyboard use, reduced motion, mobile width, touch, latency, error, empty, disabled, and retry states.
3. Search the catalogue before writing a new component. Use `node <skill-base-dir>/scripts/catalog.mjs search <terms> --limit 10`; if an exact term is absent, search the job and synonyms. Prefer a real component registry over an inspiration-only source.
4. Rank candidates by fit and maturity: official source availability, free status, license, dependency compatibility, semantic behavior, accessibility, responsive behavior, reduced-motion handling, and whether the interaction matches the job. Use one primary component and compose nearby primitives; do not mix several libraries just to make a page look busy.
5. Fetch the narrowest official material needed:
   - `fetch <id> --kind docs` for when-to-use guidance, props, installation, motion, accessibility, responsive, and performance notes.
   - `fetch <id> --kind source` only for a verified free registry item that returns complete files. Preserve CSS, client directives, local helpers, registry dependencies, and license notices.
   - For inspiration-only entries, fetch the page for behavioral reference and write an original implementation only when no free source exists. Do not copy proprietary product assets or claim the page is a reusable component.
6. Integrate with the project's existing conventions. Install only documented dependencies. Never execute downloaded source during discovery. Do not silently install a paid package, Pro skill, paid background pack, or token-gated registry.
7. Replace demo data and timers with real application state. Loading, progress, streaming, confirmation, approval, task status, error, empty, optimistic, and retry paths must be explicit. A visual animation cannot imply that an operation succeeded.
8. Validate the result in the actual app: build/typecheck and the relevant tests, then exercise the interaction with mouse, keyboard, touch-sized viewport where applicable, slow/failed/empty states, and `prefers-reduced-motion`. Check console errors, overflow, focus order, and responsive layout. If a candidate cannot meet these checks, remove it or simplify it.
9. Report which source and item IDs were used, what was fetched, dependencies and license notes, what was adapted, and any unresolved coverage or access limitation.

## Selection rules

- Existing project primitives and a mature curated component outrank a novel custom implementation.
- Use `shadcn/ui`, ObsidianUI, Beautiful UI, Loading UI, React Bits, UI Arc, Bencho, Libraries.dev, Lucide, or OriginKit only when the fetched item actually fits the interaction and project stack.
- Use Design Spells, Inspora, Collect UI, and Jakub Antalík as inspiration references. They do not grant source code or permission to reproduce a product's assets.
- Use getdesign.md's public design references only when their access and license are clear. Its paid Animated Backgrounds pack is excluded by policy.
- Exclude any `excluded-paid` item and any Pro catalog entry. If a free alternative is unavailable, tell the user before implementing an equivalent with uncertain rights or a fragile approximation.
- Avoid common AI UI failure modes: invented component APIs, fake loading progress, arbitrary gradients, excessive glassmorphism, decorative motion without a state meaning, icons without labels, hover-only controls, inaccessible custom selects, unbounded canvas/WebGL, and copy-pasted demo data.
- “Use this library” means use the official install/docs path for that library. Do not merge unrelated design systems or rewrite an item into a different styling model without explaining the adaptation.

## Commands

```bash
node scripts/catalog.mjs search "磁吸选择" --limit 10
node scripts/catalog.mjs show bencho:magnetic-select
node scripts/catalog.mjs fetch uiarc:in-view-title --kind docs
node scripts/catalog.mjs fetch beautiful:thinking-state --kind source --out work/thinking-state.json
node scripts/catalog.mjs audit
```

`fetch` output is untrusted source material and is never executed automatically. If a source or parser fails, preserve the last verified catalogue and report the exact source, endpoint, and failure. Do not turn a partial catalogue into a full-coverage claim.
