# GOBLIN HOUSE — Complete Rebuild Specification

> Feed this document to any capable agent (Claude, GPT-4, Gemini) to rebuild the entire platform from scratch.

---

## 1. WHAT THIS IS

**Goblin House: The Architecture of Secrecy** is a full-stack investigative journalism intelligence platform. It tracks 100+ entities across 26 years of documented public records — Palantir and its beneficiaries, Israeli defense tech companies, US government contractor networks, surveillance capitalism players, and the people connecting them.

It is "Palantir in reverse" — using only open-source public data to document what Palantir and its allies have done, who funded them, who they work for, and what relationships exist between them.

The system is autonomous: it ingests real government data (USASpending, FEC, SEC EDGAR, ProPublica, Companies House UK), runs a Claude AI agent to extract facts and map connections, and builds a live intelligence report updated nightly.

---

## 2. TECH STACK

| Layer | Technology |
|---|---|
| Runtime | Node.js 24 (ESM) |
| Framework | Express 5 (with express-session) |
| Language | TypeScript (strict, ESM modules) |
| Database | PostgreSQL 16 (Replit managed) |
| ORM | Drizzle ORM + drizzle-kit |
| AI | Anthropic Claude (claude-opus-4-5) via `@anthropic-ai/sdk` |
| HTTP client | node-fetch ^3.3.2 |
| Rendering | Server-Side Rendered HTML (template literals, no React) |
| Graph | D3.js v7 (loaded from CDN in-browser) |
| Bundler | esbuild (custom build.mjs) |
| Package manager | pnpm workspaces (monorepo) |
| Logging | pino + pino-pretty |

### Monorepo structure

```
/
├── artifacts/
│   └── api-server/          ← Main Express server + all routes + AI agent
│       ├── src/
│       │   ├── index.ts     ← Entry: server startup + nightly scheduler
│       │   ├── app.ts       ← Express app setup, session, middleware
│       │   ├── routes/      ← All route handlers (SSR HTML)
│       │   └── lib/         ← agent.ts, public-apis.ts, auth.ts, logger.ts, views.ts
│       ├── build.mjs        ← esbuild config
│       └── package.json
├── lib/
│   └── db/                  ← Shared DB package (@workspace/db)
│       └── src/
│           └── schema/
│               └── index.ts ← Drizzle schema — ALL tables defined here
└── package.json             ← pnpm workspace root
```

---

## 3. ENVIRONMENT VARIABLES

```
ANTHROPIC_API_KEY      — Claude API key (required for AI agent)
RESEARCH_PASSWORD      — Password for the research backend (e.g. "hunter2")
SESSION_SECRET         — Random string for express-session cookie signing
PORT                   — Port to listen on (set by Replit automatically)
DATABASE_URL           — PostgreSQL connection string (set by Replit automatically)
FEC_API_KEY            — FEC Open Data API key (optional, falls back to DEMO_KEY)
PROPUBLICA_API_KEY     — ProPublica Congress API key (optional)
COMPANIES_HOUSE_API_KEY — Companies House UK API key (optional)
```

---

## 4. DESIGN SYSTEM

### Colour palette
```css
--bg:      #0a0a0a   /* page background */
--card:    #141414   /* card / panel background */
--border:  #222222   /* borders */
--red:     #e8213a   /* primary accent — danger, severity, brand */
--teal:    #00c8b4   /* secondary accent — verified, success, links */
--text:    #d8d0c0   /* primary text */
--muted:   #6b6259   /* secondary text */
--dimmer:  #3a3a3a   /* very muted text / labels */
```

### Typography
- **UI / monospace**: `Space Mono` (Google Fonts) — all nav, labels, badges, timestamps
- **Body / document**: `Source Serif 4` (Google Fonts) — document content, synthesis text
- Base font size: `10px` root, `0.65rem` default UI text, `0.8rem` body text

### Layout rules
- Max width: `1100px` centered
- Two-column grid on desktop for feed/cards: `grid-template-columns: 1fr 1fr`
- Sidebar: `260px` fixed left for graph, research pages
- Card padding: `1.2rem`
- All borders: `1px solid var(--border)`

### Shared HTML shell (every page)
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{pageTitle} — Goblin House</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Source+Serif+4:wght@300;400;600&display=swap" rel="stylesheet">
  <style>
    /* CSS variables, reset, layout, nav */
  </style>
</head>
<body>
  <nav><!-- left sidebar: logo + nav links --></nav>
  <main>{pageContent}</main>
</body>
```

### Navigation sidebar (all pages)
```
GOBLIN HOUSE
THE ARCHITECTURE OF SECRECY
---
COMMAND CENTRE    → /research  (auth required)
ENTITIES          → /entities  (public)
SOURCES           → /sources   (auth required)
FACTS             → /facts     (auth required)
CLAIMS            → /claims    (auth required)
REVIEW QUEUE      → /review    (auth required)
RESEARCH          → /research  (auth required)
DOCUMENTS         → /documents (auth required)
GRAPH             → /graph     (public)
AGENT             → /agent     (auth required)
---
[LOGOUT]  (if authenticated)
```

---

## 5. DATABASE SCHEMA (complete)

Use Drizzle ORM with PostgreSQL. Run `pnpm --filter @workspace/db run push` to migrate.

```typescript
// lib/db/src/schema/index.ts
import { pgTable, serial, text, boolean, timestamp, integer, jsonb, varchar } from "drizzle-orm/pg-core";

export const entities = pgTable("entities", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  slug: varchar("slug", { length: 255 }).notNull().unique(),
  type: varchar("type", { length: 50 }).notNull().default("person"),
  // type values: "person" | "company" | "institution" | "instrument" | "contract" | "legal_case"
  description: text("description"),
  role: text("role"),
  status: varchar("status", { length: 50 }).notNull().default("active"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow(),
  metadata: jsonb("metadata"),
});

export const connections = pgTable("connections", {
  id: serial("id").primaryKey(),
  entityAId: integer("entity_a_id").notNull().references(() => entities.id),
  entityBId: integer("entity_b_id").notNull().references(() => entities.id),
  relationshipType: text("relationship_type").notNull(),
  description: text("description"),
  firstDocumented: text("first_documented"),   // year string e.g. "2003"
  lastDocumented: text("last_documented"),
  documented: boolean("documented").notNull().default(false),
  confidence: varchar("confidence", { length: 50 }).notNull().default("secondary"),
  // confidence values: "primary" | "secondary" | "inferential"
  sourceIds: jsonb("source_ids").$type<number[]>().default([]),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const sources = pgTable("sources", {
  id: serial("id").primaryKey(),
  entityId: integer("entity_id").references(() => entities.id),
  sourceType: varchar("source_type", { length: 100 }).notNull().default("news"),
  // sourceType values: "contract" | "sec_filing" | "fec_record" | "government_disclosure"
  //                    | "court_document" | "parliamentary_record" | "news"
  title: text("title").notNull(),
  url: text("url"),
  publication: text("publication"),
  date: text("date"),
  rawContent: text("raw_content"),
  processed: boolean("processed").notNull().default(false),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const facts = pgTable("facts", {
  id: serial("id").primaryKey(),
  entityId: integer("entity_id").notNull().references(() => entities.id),
  factText: text("fact_text").notNull(),
  dateOccurred: text("date_occurred"),
  sourceId: integer("source_id").references(() => sources.id),
  confidence: varchar("confidence", { length: 50 }).notNull().default("secondary"),
  verified: boolean("verified").notNull().default(false),
  verificationDate: text("verification_date"),
  verificationSource: text("verification_source"),
  flaggedForReview: boolean("flagged_for_review").notNull().default(false),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const claims = pgTable("claims", {
  id: serial("id").primaryKey(),
  factIds: jsonb("fact_ids").$type<number[]>().default([]),
  claimText: text("claim_text").notNull(),
  claimType: varchar("claim_type", { length: 50 }).notNull().default("structural"),
  strength: varchar("strength", { length: 50 }).notNull().default("moderate"),
  chapterRelevance: text("chapter_relevance"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const researchJobs = pgTable("research_jobs", {
  id: serial("id").primaryKey(),
  jobType: varchar("job_type", { length: 100 }).notNull(),
  // jobType values: "research_entity" | "extract_facts" | "map_connections" | "verify_fact"
  //                 | "synthesise" | "compare_document" | "detect_conflicts"
  //                 | "draft_section" | "ingest_public_data"
  status: varchar("status", { length: 50 }).notNull().default("queued"),
  // status values: "queued" | "running" | "completed" | "failed"
  // IMPORTANT: completion status is "completed" NOT "complete"
  input: jsonb("input"),
  output: jsonb("output"),
  entityId: integer("entity_id").references(() => entities.id),
  tokensUsed: integer("tokens_used").default(0),
  costEstimate: text("cost_estimate"),
  errorMessage: text("error_message"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  completedAt: timestamp("completed_at"),  // NOTE: no updatedAt on this table
});

export const documents = pgTable("documents", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  version: integer("version").notNull().default(1),
  content: text("content"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow(),
});

export const passages = pgTable("passages", {
  id: serial("id").primaryKey(),
  documentId: integer("document_id").notNull().references(() => documents.id),
  passageText: text("passage_text").notNull(),
  entityIds: jsonb("entity_ids").$type<number[]>().default([]),
  claimIds: jsonb("claim_ids").$type<number[]>().default([]),
  confidence: varchar("confidence", { length: 50 }).default("secondary"),
  sourceIds: jsonb("source_ids").$type<number[]>().default([]),
  needsReview: boolean("needs_review").notNull().default(false),
});

export const syntheses = pgTable("syntheses", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  content: text("content").notNull(),
  jobIds: jsonb("job_ids").$type<number[]>().default([]),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const findings = pgTable("findings", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  findingType: varchar("finding_type", { length: 100 }).notNull().default("conflict_of_interest"),
  description: text("description").notNull(),
  involvedEntities: jsonb("involved_entities").$type<string[]>().default([]),
  severity: varchar("severity", { length: 50 }).notNull().default("significant"),
  // severity: "critical" | "significant" | "moderate"
  publicInterest: text("public_interest"),
  evidenceSummary: text("evidence_summary"),
  sourceTypes: jsonb("source_types").$type<string[]>().default([]),
  jobId: integer("job_id"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const auditLog = pgTable("audit_log", {
  id: serial("id").primaryKey(),
  action: text("action").notNull(),
  entityId: integer("entity_id"),
  userNote: text("user_note"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const subscribers = pgTable("subscribers", {
  id: serial("id").primaryKey(),
  email: text("email").notNull().unique(),
  subscribedAt: timestamp("subscribed_at").notNull().defaultNow(),
  active: boolean("active").notNull().default(true),
  source: varchar("source", { length: 100 }).default("report_page"),
});

export const schedulerState = pgTable("scheduler_state", {
  id: serial("id").primaryKey(),
  key: varchar("key", { length: 100 }).notNull().unique(),
  // keys used: "last_nightly_run" | "last_nightly_status" | "next_nightly_run"
  value: text("value"),
  updatedAt: timestamp("updated_at").notNull().defaultNow(),
});
```

---

## 6. AUTH SYSTEM

- **Session-based auth** using `express-session` with `connect-pg-simple` (stores sessions in PostgreSQL)
- Single password stored in `RESEARCH_PASSWORD` environment variable
- 24-hour cookie (`maxAge: 86400000`)
- Login page at `GET /login` with `POST /login`
- Logout at `POST /logout`

**Public routes** (no auth needed):
- `/` — home/report page
- `/report` — intelligence report
- `/graph` — connection graph
- `/methodology` — source methodology
- `/entity/:slug` — entity profiles
- `/document` — document reader
- `/synthesis/:id` — synthesis pages
- `/findings` — findings list
- `/subscribe` — email subscribe POST
- `/healthz` — health check

**Auth-required routes** (redirect to `/login` if not authenticated):
- Everything under `/research`, `/agent`, `/sources`, `/facts`, `/claims`, `/review`, `/admin/*`

**Auth middleware pattern:**
```typescript
export function requireAuth(req, res, next) {
  const sess = req.session as any;
  if (sess?.authenticated) return next();
  res.redirect("/login?next=" + encodeURIComponent(req.originalUrl));
}
```

---

## 7. ALL ROUTES

### GET / and GET /report
Public intelligence report page. Shows:
- Hero headline: "THE ARCHITECTURE OF SECRECY — INTELLIGENCE REPORT"
- Stats bar: entities tracked, facts collected, connections mapped, conflicts found, years covered
- Nightly scheduler status strip (sources listed, last run, next run)
- **Recent Intelligence feed** (last 7 days, max 20 items, sorted by recency desc): merged list of:
  - New findings (with severity badge, evidence URL or link to /findings)
  - New entities (with entity type badge, "Entity profile →" link)
  - New connections (entity A ↔ entity B, relationship type, confidence, "View in graph →" link)
  - New sources (source type label, URL if real external URL)
- Document sections (if any documents exist)
- Synthesis entries
- "Stay Informed" email subscribe form (dark themed input, POST /subscribe)

### GET /graph
Public D3.js force-directed graph. Features:
- All entities as nodes (colored by type), all connections as edges
- Left filter sidebar with:
  - Entity type checkboxes (Person, Company, Institution, Instrument, Contract, Legal Case)
  - Relationship type checkboxes (scrollable list of all unique rel types in DB)
  - Confidence checkboxes (Primary, Secondary, Inferential)
  - **Year Range dual slider** (from `firstDocumented` years in data, default full range)
    - Out-of-range edges dimmed to opacity 0.06 / color #181818, NOT removed
    - Null-dated connections always shown at full opacity
  - Reset button (clears all filters including year range)
- Search box: debounced 200ms, highlights matching nodes with teal ring
- Live node/edge count display
- Node click: panel showing entity name, type, connection count
- Legend: Person (teal), Company (gold), Institution (purple), Instrument (red), Contract (dark red), Legal Case (gray)
- Primary connections: solid line. Inferential: dashed line.

**D3 rendering (client-side script injected into page):**
```javascript
// Data injected as JSON: window.__GRAPH_DATA__ = { nodes: [...], links: [...] }
// nodes: { id, name, type, slug }
// links: { source, target, confidence, relationshipType, firstDocumented }
```

### GET /methodology
Public page explaining:
- Confidence tier system (Primary / Secondary / Inferential) with card descriptions
- Source table: USASpending, SEC EDGAR, FEC Open Data, ProPublica/LDA, Companies House UK
- AI agent constraints (what it can/cannot do)
- Auto-discovery process
- What we don't do (no unverified claims, no anonymous sources)
- Corrections policy

### GET /entities
Auth-gated list of all entities. Shows type, status, source/fact/connection counts. Filter by type.

### GET /entity/:slug
Public entity profile page:
- Name, type badge, role, description
- All facts (sorted by confidence, then date)
- All connections (A↔B format, with relationship type, confidence, year range)
- All sources (with URLs where available, source type badge)
- If authenticated: edit/delete/queue research buttons

### GET /sources, GET /sources/health
Auth-required. Source list and health dashboard:
- Per-source-type counts (contracts, SEC filings, FEC records, etc.)
- Sources with real external URLs vs AI-generated
- POST /sources/health/reingest/:entityId — queue re-ingestion job

### GET /facts
Auth-required. All facts with confidence levels. Filter by entity, confidence.

### GET /claims
Auth-required. All claims grouped by type.

### GET /review
Auth-required. Facts flagged for review. Approve/reject controls.

### GET /research
Auth-required. Research command centre:
- Scheduler status card (last run time, status, next run UTC + countdown)
- Data freshness panel: per-entity grid showing:
  - URL source count (from `sources` table where url not null)
  - AI-generated source count (where url is null or starts with "ai-generated")
  - Days since last completed `ingest_public_data` job (from `researchJobs.completedAt`)
  - Re-ingest button per entity
- Queue controls: research entity, run synthesis, detect conflicts, full pipeline
- Active jobs display with status badges

### GET /agent
Auth-required. AI agent control panel:
- Agent status (running/paused, calls this minute, daily cost vs $25 limit)
- Start/stop/pause/resume controls
- Daily cost override button
- Queue management (all queued jobs visible)
- Manual job queueing forms

### GET /document
Public document reader. Reads `documents` table, renders with Source Serif 4 font, dark background.

### GET /synthesis/:id
Public synthesis viewer. Full markdown-like formatted content.

### GET /findings
Public findings list. Grouped by severity (critical → significant → moderate).

### POST /subscribe
Public. Body: `{ email }`. Validates format, inserts into `subscribers` table.
- Success: redirect to `/report?subscribed=1` with 3s banner
- Duplicate: friendly message
- Invalid: error page

### GET /admin/subscribers.csv
Auth-required. Downloads all active subscribers as CSV.

### GET /healthz
Returns `{ "status": "ok" }` — used for deployment health check.

---

## 8. AI AGENT SYSTEM

File: `src/lib/agent.ts`

### Rate limiting
- Max **8 Anthropic API calls per minute** (in-memory counter, resets on minute boundary)
- **$25/day hard cap** (accumulated cost tracked in memory, resets at midnight UTC)
- Manual override flag available

### Cost tracking
- `claude-opus-4-5`: $0.003 per 1K input tokens, $0.015 per 1K output tokens
- Tracked in memory: `dailyCost`, `totalTokensToday`, `callsThisMinute`

### Job queue processor
Polls `research_jobs` table every 5 seconds. Picks up `status = "queued"` jobs one at a time:

| `jobType` | What it does |
|---|---|
| `research_entity` | Calls Claude with 6 query prompts (SEC, FEC, contracts, disclosure, court records, parliamentary). Stores sources + facts. Queues `map_connections` afterward. |
| `extract_facts` | Reads a source's `rawContent`, asks Claude to extract discrete facts as JSON array. |
| `map_connections` | Reads entity facts, asks Claude to identify connections to other known entities. Deduplicates before insert. |
| `verify_fact` | Checks a fact against its source content. Updates `verified`, `confidence`, `flaggedForReview`. |
| `synthesise` | Full intelligence brief using all primary/secondary/inferential facts + connections. 6-section structured output. Stores in `syntheses` table. |
| `compare_document` | Compares a document's claims against verified facts DB. Returns unsupported claims, missing facts, discrepancies. |
| `detect_conflicts` | Finds conflicts of interest across all entities. Looks for: undisclosed relationships, regulatory capture, simultaneous public+private interests, hidden funding. Stores results in `findings` table. |
| `draft_section` | Drafts a document section based on verified facts. |
| `ingest_public_data` | Calls public APIs (USASpending, FEC, SEC, ProPublica, Companies House) and stores real records. |

### Queue helper exports
```typescript
export function queueEntityResearch(entityId: number): Promise<void>
export function queuePublicDataIngestion(entityId: number): Promise<void>
export function queuePublicDataIngestionAll(): Promise<void>  // queues for every entity
export function queueConflictDetection(): Promise<void>
export function queueSynthesis(entityIds: number[]): Promise<void>
export function queueFullPipeline(entityId: number): Promise<void>
```

---

## 9. PUBLIC DATA INGESTION

File: `src/lib/public-apis.ts`

Fetches from real government APIs for each entity:

| API | What it fetches | Auth |
|---|---|---|
| USASpending.gov | Federal contracts, grants, loans | None (public) |
| SEC EDGAR | SEC filing search | None (public) |
| FEC Open Data | Campaign finance records | `FEC_API_KEY` (DEMO_KEY works) |
| ProPublica Congress / LDA | Lobbying disclosure records | `PROPUBLICA_API_KEY` |
| Companies House UK | Company registrations, officers | `COMPANIES_HOUSE_API_KEY` + Basic auth |
| OpenCorporates | Company officer search | None (rate limited) |

Each API call:
1. Normalizes entity name (removes "The ", "Inc", etc.)
2. Searches the API with 20-second timeout
3. Extracts real source URLs from responses
4. Stores sources in `sources` table with `url` set to the real external URL
5. Extracts facts from structured API responses (no AI needed for public data)
6. Returns `discoveredRecipients` — new entity names found that aren't in the DB yet

**Auto-discovery**: when `ingest_public_data` finds new entity names in the data, those are queued as new entities to ingest next.

### Source type → sourceType mapping
```
USASpending contracts → "contract"
SEC EDGAR filings    → "sec_filing"
FEC records          → "fec_record"
ProPublica lobbying  → "government_disclosure"
Companies House      → "government_disclosure"
```

---

## 10. NIGHTLY SCHEDULER

File: `src/index.ts`

- Fires at **00:30 UTC** every night
- On server startup: checks `last_nightly_run` from `scheduler_state` table
  - If >23 hours since last run (or never run): immediately queues ingestion
  - Otherwise: waits until next 00:30 UTC
- Persists 3 keys to `scheduler_state`:
  - `last_nightly_run` — ISO timestamp of last run start
  - `last_nightly_status` — "running" | "completed" | "failed: {message}"
  - `next_nightly_run` — ISO timestamp of next scheduled run
- Uses `setTimeout().unref()` so process can exit cleanly if needed
- Nightly run: calls `queuePublicDataIngestionAll()` then `queueConflictDetection()`

---

## 11. SEED DATA — INITIAL ENTITIES

The platform tracks these entity categories. Seed with ~99 entities across these groups:

**Palantir ecosystem**: Palantir Technologies, Peter Thiel, Alex Karp, Joe Lonsdale, Stephen Cohen, Nathan Gettings, Karp's inner circle, Palantir board members

**Israeli defense tech**: NSO Group, Rafael Advanced Defense Systems, Elbit Systems, NICE Systems, Cellebrite, Check Point Software, Shalev Hulio, unit 8200 veterans

**Government contractors**: Booz Allen Hamilton, SAIC, Leidos, CACI International, ManTech, BAE Systems US

**Financial nexus**: Founders Fund, Tiger Global, In-Q-Tel (CIA venture arm), Valar Ventures, Bridgewater Associates, Renaissance Technologies, BlackRock, Vanguard

**Political figures**: figures connected to the above through FEC records, board positions, or government contracts

**Instruments**: Project Maven, Maven Smart System, Starshield, PRISM

For each entity, store: `name`, `slug` (lowercase-hyphenated), `type`, `role`, `description`

---

## 12. BUILD INSTRUCTIONS FOR AGENT

### Step 1: Monorepo setup
```
pnpm init
pnpm add -w typescript @types/node
Create pnpm-workspace.yaml listing artifacts/* and lib/*
```

### Step 2: Database package
```
lib/db/package.json  — @workspace/db
lib/db/src/schema/index.ts  — all tables as above
lib/db/src/index.ts  — export { db } using drizzle(postgres(DATABASE_URL))
pnpm --filter @workspace/db run push  — to migrate
```

### Step 3: Express server
```
artifacts/api-server/
├── src/
│   ├── index.ts    — PORT validation + nightly scheduler + app.listen
│   ├── app.ts      — express(), session, cookie-parser, body-parser, router
│   ├── routes/     — one file per route group (see section 7)
│   └── lib/
│       ├── agent.ts        — AI job processor (section 8)
│       ├── public-apis.ts  — real API clients (section 9)
│       ├── auth.ts         — requireAuth / isAuthenticated middleware
│       ├── views.ts        — layout(title, body, options) → full HTML string
│       └── logger.ts       — pino logger
├── build.mjs       — esbuild bundle to dist/
└── package.json    — dev/build/start scripts
```

### Step 4: Views helper
All pages use a `layout(title, content, { showNav, authenticated })` function that wraps content in the full HTML shell with nav sidebar, Google Fonts, CSS variables, and responsive styles.

### Step 5: Session config
```typescript
import session from "express-session";
import connectPgSimple from "connect-pg-simple";
const PgStore = connectPgSimple(session);
app.use(session({
  store: new PgStore({ conString: process.env.DATABASE_URL }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 86400000, httpOnly: true, secure: process.env.NODE_ENV === "production" }
}));
```

### Step 6: esbuild config
```javascript
// build.mjs
import * as esbuild from "esbuild";
await esbuild.build({
  entryPoints: ["src/index.ts", "src/seed.ts"],
  bundle: true,
  platform: "node",
  format: "esm",
  outdir: "dist",
  outExtension: { ".js": ".mjs" },
  sourcemap: true,
  packages: "external",  // don't bundle node_modules
});
```

### Step 7: package.json scripts
```json
{
  "scripts": {
    "dev": "export NODE_ENV=development && pnpm run build && pnpm run start",
    "build": "node ./build.mjs",
    "start": "node --enable-source-maps ./dist/index.mjs",
    "seed": "pnpm run build && node --enable-source-maps ./dist/seed.mjs"
  }
}
```

---

## 13. KEY IMPLEMENTATION NOTES

1. **All HTML is server-rendered** — no React, no client JS frameworks. Pages are template literal strings.

2. **D3 graph is client-side only** — D3 loaded from CDN (`https://d3js.org/d3.v7.min.js`), graph data injected as `window.__GRAPH_DATA__` JSON.

3. **Job completion status is `"completed"`** — not `"complete"`. This is critical for scheduler and freshness queries.

4. **`researchJobs` has `completedAt` not `updatedAt`** — use `completedAt` when querying job completion timestamps.

5. **Source type values**: `"contract"`, `"sec_filing"`, `"fec_record"`, `"government_disclosure"` — these are the actual stored values. Display labels: CONTRACT, SEC, FEC, GOV.

6. **Session cookie**: set `secure: true` only in production (HTTPS). Dev uses HTTP.

7. **node-fetch v3**: ESM-only. Import as `import fetch from "node-fetch"`. Do not use require().

8. **Date range slider**: uses `firstDocumented` field on connections (text year like "2003"). Out-of-range connections are dimmed, never hidden. Null-dated connections always show at full opacity.

9. **Public vs private routes**: The research backend is auth-protected. The public-facing report, graph, methodology, entity profiles, findings, and document reader require NO login. This is intentional — the intelligence is meant to be readable by anyone.

10. **AI rate limiting is in-memory** — resets on server restart. On autoscale deployment, each cold start resets the counter.

11. **Scheduler catch-up**: on startup, if `last_nightly_run` is >23h ago, immediately run ingestion. This compensates for autoscale sleep.

12. **`PORT` env var is required** — server throws on startup if missing.

13. **Health check at `/healthz`** — must return 200 `{"status":"ok"}` for deployment health checks.

---

## 14. WHAT THIS PLATFORM DOES NOT DO

- No tracking of private individuals without public record basis
- No anonymous sources — every fact traces to a public record
- No fabrication — AI agent explicitly instructed to return "not found" rather than invent
- No paywalled content — only USASpending, FEC, SEC, ProPublica, Companies House (all free/public)
- No scraping of private websites — only official government APIs and public registries

---

## 15. SAMPLE PROMPT TO REBUILD

> Build "Goblin House: The Architecture of Secrecy" — a full-stack investigative journalism intelligence platform. Use the GOBLIN_HOUSE_SPEC.md as the complete specification. The stack is Node.js/Express with TypeScript, PostgreSQL/Drizzle ORM, server-side rendered HTML (no React), and a Claude AI agent for research automation. Start with the database schema, then build the Express server with all routes, then implement the AI agent and public API ingestion layer. The platform tracks 100+ entities across 26 years of public records including Palantir, Israeli defense tech, and US government contractors. Style is dark investigative aesthetic — black background, red and teal accents, Space Mono font for UI. All public routes require no login. The research backend requires the RESEARCH_PASSWORD env var.
