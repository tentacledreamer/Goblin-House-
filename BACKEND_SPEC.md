# Goblin House — Backend Specification

**Purpose:** Investigative journalism intelligence platform tracking 100+ entities across 26 years. Tracks Palantir beneficiaries, Israeli defense tech, and government contractor networks using only public sources. All data comes from USASpending.gov, FEC, SEC EDGAR, Companies House, ProPublica, and OpenCorporates — no scraped or paywalled sources.

---

## Stack

| Layer | Technology |
|---|---|
| Runtime | Node.js 24, TypeScript, ESM |
| Framework | Express.js (SSR HTML — no frontend framework) |
| Database | PostgreSQL 16, Drizzle ORM |
| AI | Anthropic `claude-opus-4-5` |
| HTTP client | `node-fetch` ^3.3.2 |
| Package manager | pnpm workspace |
| Build | `tsup` → `dist/index.mjs` |

**Workspace packages:**
- `@workspace/api-server` — the main Express app (`artifacts/api-server/`)
- `@workspace/db` — Drizzle schema + client (`lib/db/`)
- `@workspace/mockup-sandbox` — design preview server (unrelated to production)

**DB migration:** `pnpm --filter @workspace/db run push`

---

## Database Schema (13 tables)

### `entities`
Core nodes of the network. Every person, company, or government agency is an entity.

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| name | text | Display name |
| slug | varchar(255) unique | URL-safe identifier — used in `/entity/:slug` |
| type | varchar(50) | `person`, `company`, `government_agency` |
| description | text | |
| role | text | e.g. "CEO", "US Senator" |
| status | varchar(50) | `active`, `inactive` |
| metadata | jsonb | Arbitrary extra fields |

### `connections`
Edges in the network graph between two entities.

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| entityAId | integer → entities.id | |
| entityBId | integer → entities.id | |
| relationshipType | text | e.g. "board_member", "investor", "contractor" |
| description | text | |
| firstDocumented | text | Year string e.g. "2019" |
| lastDocumented | text | |
| documented | boolean | True = backed by primary source |
| confidence | varchar(50) | `primary`, `secondary`, `inferential` |
| sourceIds | jsonb `number[]` | Array of source IDs |

### `sources`
Every document, filing, or record that provides evidence.

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| entityId | integer → entities.id | |
| sourceType | varchar(100) | **Stored values:** `contract`, `sec_filing`, `fec_record`, `government_disclosure` |
| title | text | |
| url | text | Direct link to source document |
| publication | text | e.g. "USASpending.gov", "SEC EDGAR" |
| date | text | Year or ISO date string |
| rawContent | text | Full text of the source |
| processed | boolean | Whether facts have been extracted |

**Display label map:**
- `contract` → CONTRACT
- `sec_filing` → SEC
- `fec_record` → FEC
- `government_disclosure` → GOV

### `facts`
Discrete, citable claims extracted from sources.

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| entityId | integer → entities.id | |
| factText | text | The claim |
| dateOccurred | text | When it happened |
| sourceId | integer → sources.id | |
| confidence | varchar(50) | `primary`, `secondary`, `inferential` |
| verified | boolean | Set by `verify_fact` agent job |
| verificationDate | text | |
| verificationSource | text | Explanation from agent |
| flaggedForReview | boolean | Set when verification contradicts claim |

### `claims`
Higher-level structured claims built from multiple facts (for document drafting).

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| factIds | jsonb `number[]` | Supporting facts |
| claimText | text | |
| claimType | varchar(50) | `structural`, `financial`, `political` |
| strength | varchar(50) | `strong`, `moderate`, `weak` |
| chapterRelevance | text | Which section of the report this belongs in |

### `researchJobs`
The agent job queue. All AI work flows through this table.

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| jobType | varchar(100) | See job types below |
| status | varchar(50) | `queued`, `running`, `completed`, `failed` |
| input | jsonb | Job parameters |
| output | jsonb | Result data |
| entityId | integer → entities.id | |
| tokensUsed | integer | |
| costEstimate | text | Dollar amount as string e.g. "0.0234" |
| errorMessage | text | |
| createdAt | timestamp | |
| completedAt | timestamp | **NOTE: this column is `completedAt` NOT `updatedAt`** |

**⚠ Critical gotcha:** `researchJobs` has `completedAt`, **not** `updatedAt`. Using `.updatedAt` will cause a runtime crash.

**Job completion status is `"completed"` not `"complete"`.**

### `documents`
Long-form narrative documents (the book / report being built).

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| title | text | |
| version | integer | |
| content | text | Full markdown/prose content |

### `passages`
Sections of a document linked to entities, claims, and sources.

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| documentId | integer → documents.id | |
| passageText | text | |
| entityIds | jsonb `number[]` | |
| claimIds | jsonb `number[]` | |
| sourceIds | jsonb `number[]` | |
| needsReview | boolean | |

### `syntheses`
AI-generated intelligence briefs produced by the `synthesise` job.

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| title | text | Auto-generated with entity names and date |
| content | text | Full markdown brief |
| jobIds | jsonb `number[]` | Which jobs produced this |

### `findings`
Specific conflict-of-interest findings produced by `detect_conflicts`.

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| title | text | |
| findingType | varchar(100) | `conflict_of_interest`, `undisclosed_relationship`, `regulatory_capture` |
| description | text | |
| involvedEntities | jsonb `string[]` | Entity names (not IDs) |
| severity | varchar(50) | `critical`, `significant`, `notable` |
| publicInterest | text | Why this matters |
| evidenceSummary | text | |
| sourceTypes | jsonb `string[]` | |
| jobId | integer | Which job produced this |

### `auditLog`
Simple event log of all write actions.

### `subscribers`
Email addresses from the subscribe form on the report page.

| Column | Type | Notes |
|---|---|---|
| id | serial PK | |
| email | text unique | |
| active | boolean | |
| source | varchar(100) | Default `"report_page"` |

### `schedulerState`
Key-value store for the nightly scheduler. Keys: `last_nightly_run`, `last_nightly_status`, `next_nightly_run`.

---

## Authentication

- Session-based, `express-session`, 24-hour cookie
- Single password via `RESEARCH_PASSWORD` environment variable
- `POST /login` validates the password; sets `req.session.authenticated = true`
- `requireAuth` middleware redirects to `/login?next=...` if not authenticated
- `isAuthenticated(req)` utility for conditional UI rendering on public routes

---

## Routes

### Public (no password required)

| Route | Description |
|---|---|
| `GET /` | Home / landing page with live stats |
| `GET /report` | Unified intelligence feed — all facts, sources, findings, syntheses in one scrollable view. Includes subscriber form. |
| `GET /graph` | D3.js force-directed network graph. Entity/type/confidence filters, date-range slider (dims links outside range), search. |
| `GET /methodology` | Static methodology page explaining sources and confidence levels |
| `GET /entity/:slug` | Individual entity profile page |
| `GET /synthesis/:id` | Individual synthesis brief |
| `GET /document/:id` | Public document reader |
| `GET /findings` | All findings |
| `GET /healthz` | Health check — returns `200 OK` plain text |

### Auth-required

| Route | Description |
|---|---|
| `GET /research` | Job queue dashboard. Shows all jobs, entity list, scheduler state, data freshness panel, synthesis list. Trigger buttons for all job types. |
| `GET /agent` | Agent control panel — start/stop/pause/resume, cost meter, daily token usage, per-entity job status. |
| `GET /entities` | Entity list with edit/add/delete |
| `GET /entity/:slug/edit` | Edit entity form |
| `POST /entity` | Create entity |
| `POST /entity/:id` | Update entity |
| `POST /entity/:id/delete` | Delete entity |
| `GET /sources` | Source list with add/delete |
| `POST /source` | Create source |
| `POST /source/:id/delete` | Delete source |
| `GET /facts` | Facts list with filter/search |
| `POST /fact` | Create fact |
| `POST /fact/:id/delete` | Delete fact |
| `GET /claims` | Claims list |
| `POST /claim` | Create claim |
| `GET /review` | Facts flagged for review (contradicted by verification) |
| `GET /download` | Download page with 7 export buttons |

### Download Endpoints (auth-required)

| Endpoint | Format | Contents |
|---|---|---|
| `GET /download/data.json` | JSON | Entities, connections, sources, syntheses — entity names resolved |
| `GET /download/facts.json` | JSON | All facts with entity names |
| `GET /download/graph.json` | JSON | Nodes + links in D3/Gephi/Obsidian format |
| `GET /download/entities.csv` | CSV | All entities |
| `GET /download/connections.csv` | CSV | All connections with entity names resolved |
| `GET /download/sources.csv` | CSV | All sources |
| `GET /download/facts.csv` | CSV | All facts with entity name |

### Agent Control Endpoints (auth-required POST)

| Endpoint | Action |
|---|---|
| `POST /agent/start` | Start agent processing |
| `POST /agent/stop` | Stop agent |
| `POST /agent/pause` | Pause agent |
| `POST /agent/resume` | Resume agent |
| `POST /agent/cost-override` | Override daily $25 cost cap |
| `POST /research/queue` | Queue a specific job type |
| `POST /research/queue-ingest` | Queue public data ingestion for one entity |
| `POST /research/queue-ingest-all` | Queue ingestion for all entities |
| `POST /research/queue-conflicts` | Queue conflict detection |
| `POST /research/queue-pipeline` | Queue full pipeline for one entity |
| `POST /subscribe` | Add email to subscribers |

---

## Agent Job System

The agent is a simple in-process job queue (no external queue like Bull/BullMQ). It polls `researchJobs` every 5 seconds for queued work.

### Rate Limits
- 8 Anthropic API calls per minute (tracked in-memory, resets on window)
- $25/day hard cap (in-memory, resets at midnight, overridable via UI)
- Model: `claude-opus-4-5`
- Cost: $0.003/1K input tokens, $0.015/1K output tokens

### Job Types

| jobType | Description |
|---|---|
| `research_entity` | Calls Claude 6 times (once per source suffix: SEC, FEC, contracts, disclosure, court, parliamentary). Writes sources + facts. Auto-queues `map_connections` on completion. |
| `extract_facts` | Extracts discrete facts from a source's `rawContent`. Marks source as `processed`. |
| `map_connections` | Given an entity's facts + all known entities, asks Claude to identify connections. Deduplicates before insert. |
| `verify_fact` | Cross-checks a fact against its source. Sets `verified`, `confidence`, `flaggedForReview`. |
| `synthesise` | Produces a structured intelligence brief (6 sections) from facts + connections for a set of entity IDs (or all entities). Saves to `syntheses`. |
| `compare_document` | Compares a document's content against verified facts. Returns unsupported claims, missing facts, discrepancies. |
| `detect_conflicts` | Scans all entities/connections/facts for conflicts of interest, undisclosed relationships, regulatory capture. Saves to `findings`. |
| `draft_section` | Drafts a section of a document from facts and claims. |
| `ingest_public_data` | Calls all public APIs for an entity and writes real primary-source records to DB. |

### Queue Functions (exported from `lib/agent.ts`)

```typescript
queueEntityResearch(entityId: number)
queueSynthesis(entityIds: number[])
queueConflictDetection()
queueDraftSection(documentId: number)
queueFullPipeline(entityId: number) // research → map_connections → synthesise
queuePublicDataIngestion(entityId: number)
queuePublicDataIngestionAll() // queues ingest for every entity in DB
```

---

## Public Data Ingestion (lib/public-apis.ts)

Real HTTP calls to free public APIs. All writes go directly to `sources` + `facts` tables with `confidence: "primary"`.

### APIs Used

| API | Base URL | Key Required |
|---|---|---|
| USASpending.gov | `https://api.usaspending.gov/api/v2` | No |
| SEC EDGAR full-text search | `https://efts.sec.gov/LATEST/search-index` | No |
| FEC | `https://api.open.fec.gov/v1` | `FEC_API_KEY` (falls back to `DEMO_KEY`) |
| OpenCorporates | `https://api.opencorporates.com/v0.4` | No |
| Companies House (UK) | `https://api.company-information.service.gov.uk` | `COMPANIES_HOUSE_API_KEY` (skips if unset) |
| ProPublica Congress/Lobbying | `https://api.propublica.org/congress/v1` | `PROPUBLICA_API_KEY` (skips if unset) |

### Per Entity-Type Routing

**Person:** FEC donations + EDGAR person filings + ProPublica lobbying

**Company:** USASpending contracts + EDGAR company filings + FEC committee spending + OpenCorporates + Companies House (UK)

**Government agency:** USASpending by agency + EDGAR + ProPublica lobbying

All API calls have a 20-second timeout. Non-OK responses and errors are logged as warnings and skipped — the pipeline continues.

---

## Nightly Scheduler

Runs at 00:30 UTC every day. Persists last-run state in `schedulerState` table so it survives server restarts.

**Catch-up logic:** On startup, if `last_nightly_run` exists and is more than 23 hours ago, it runs immediately (compensates for Replit sleep periods on autoscale deployment).

**What it does:** `queuePublicDataIngestionAll()` then `queueConflictDetection()`.

---

## Environment Variables

| Variable | Required | Purpose |
|---|---|---|
| `PORT` | Yes | Server bind port — app crashes if missing or invalid |
| `RESEARCH_PASSWORD` | Yes | Single password for the research backend |
| `SESSION_SECRET` | Yes | Express session signing secret |
| `ANTHROPIC_API_KEY` | Yes | Claude API access |
| `FEC_API_KEY` | No | Higher rate limits for FEC API (defaults to DEMO_KEY) |
| `COMPANIES_HOUSE_API_KEY` | No | UK Companies House (UK companies skipped if unset) |
| `PROPUBLICA_API_KEY` | No | ProPublica lobbying data (skipped if unset) |

---

## Key Files

```
artifacts/api-server/
  src/
    index.ts          — server startup, nightly scheduler
    app.ts            — Express app setup, sessions, middleware
    routes/
      index.ts        — router assembly
      auth.ts         — login/logout
      home.ts         — landing page
      report.ts       — unified feed + subscriber form
      graph.ts        — D3 graph page + data endpoint
      research.ts     — job queue dashboard
      agent.ts        — agent control panel
      entities.ts     — entity CRUD
      sources.ts      — source CRUD
      facts.ts        — facts list/CRUD
      claims.ts       — claims
      review.ts       — flagged facts
      document.ts     — document reader
      methodology.ts  — static methodology page
      download.ts     — all 7 export endpoints
      health.ts       — /healthz
    lib/
      agent.ts        — Claude integration, job queue, all job implementations
      public-apis.ts  — 6 public API integrations
      auth.ts         — requireAuth, isAuthenticated, optionalAuth
      views.ts        — layout(), nav sidebar, escHtml(), formatDate()
      logger.ts       — pino logger

lib/db/
  src/
    schema/index.ts   — all 13 table definitions + TypeScript types
    index.ts          — Drizzle client (uses DATABASE_URL)
```

---

## Design System (for SSR HTML generation)

All pages are rendered via `layout(title, body, req)` in `lib/views.ts` — pure string concatenation, no templating engine.

| Token | Value | Use |
|---|---|---|
| `--bg` | `#0a0a0a` | Page background |
| `--card` | `#141414` | Card / panel background |
| `--border` | `#222` | Border color |
| `--red` | `#e8213a` | Accent / alerts / logo |
| `--teal` | `#00c8b4` | Secondary accent / links |
| `--text` | `#d8d0c0` | Body text |
| `--muted` | `#6b6259` | Secondary text |
| UI font | Space Mono | Headers, labels, nav |
| Body font | Source Serif 4 | Document/reading content |

Nav sidebar links (always visible): Intelligence Report, Network Graph, Entities, Sources, Facts, Research, Agent, Methodology, Download Data

---

## Current Data Counts (as of last check)

- 99 entities
- 261 connections
- 479 sources
- 2,505 facts
- 2 syntheses
- 0 findings (conflict detection not yet run on current data)

---

## Common Gotchas

1. **`researchJobs.completedAt` not `.updatedAt`** — the table has no `updatedAt` column
2. **Job status is `"completed"` not `"complete"`**
3. **Source type stored values** are `contract`, `sec_filing`, `fec_record`, `government_disclosure` — not their display labels
4. **Deployment target is `autoscale`** (not `vm`) — user doesn't have VM plan
5. **The agent is in-process** — restarting the server resets `agentRunning`, `dailyCost`, etc. (in-memory state). The job queue itself persists in the DB.
6. **Graph date-range slider** uses `isLinkInYearRange()` — null-dated connections are always shown regardless of range
7. **Public pages do not require auth** — `/report`, `/graph`, `/methodology`, `/entity/:slug`, `/synthesis/:id` are all open
