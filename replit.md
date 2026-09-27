# Goblin House

## Overview
Goblin House is an investigative journalism intelligence platform that uses AI research agents ("Goblins") to uncover undisclosed conflicts, regulatory capture, and dual loyalties in government, finance, and technology. It tracks over 900 entities, generating deep insights, public reports, and social media content. The platform aims to promote transparency and accountability by exposing hidden influences and relationships.

## User Preferences
- All public pages should include `<link rel="canonical">` pointing to `https://goblinhouse.net/...`
- Open Graph and Twitter Card meta tags should be present on all public pages.
- The OG image should be served from `/opengraph.jpg`.
- The AI agent should automatically pause and re-queue jobs upon credit exhaustion errors from the Anthropic API.
- Investigation follow-up automation should queue up to 3 `directed_inquiry` jobs for significant/critical inference results, capped at 5 per entity.
- Cross-goblin collaboration should automatically queue up to 2 `directed_inquiry` handoff jobs for entity mentions belonging to other goblins' watchlists.
- The nightly scheduler should queue public data ingestion, conflict detection, and threat assessment. Social post generation should trigger automatically after threat assessment completion.
- The nightly scheduler automatically ingests voting records from Congress.gov/ProPublica APIs for all elected officials and runs contradiction analysis on any new data.

## Goblin Brain integration (Task #358)

The local Goblin Brain Windows desktop client drives the platform's
backlog review surfaces over a single queue-agnostic JSON API at
`/api/v1/...`. Authentication is bearer-only via personal API tokens
minted at `/admin/personal-tokens` (cleartext shown exactly once,
scrypt hash + 16-char prefix persisted; revocable from the same UI).

Adding a new review queue:
1. Create `artifacts/api-server/src/lib/review-queues/queues/<id>.ts`
   exporting `defineReviewQueue({ id, decisionVerbs, list, getItem,
   countPending, applyDecision, ... })`.
2. Import + `registerReviewQueue(...)` in
   `artifacts/api-server/src/lib/review-queues/index.ts`.
3. The endpoints under `/api/v1/queues/...` automatically dispatch to
   the new queue. No router changes needed.

Decisions MUST mirror the existing SSR admin handler so the API and the
HTML page can never disagree (audit_log entries, status flips, side
effects all match). Six representative queues are wired in this round:
proposed-contradictions, engine-contradictions, flagged-facts,
queued-research-jobs, draft-crinkle-notes, and sightings-handoff. The
remaining ~19 surfaces will be added by following the recipe above
(tracked as a follow-up task).

The investigate endpoint (`POST /api/live/queues/:id/items/:itemId/investigate`)
operates in two modes depending on queue type:

**Research mode** (for `ingest_public_data`, `directed_inquiry`, `research_entity`
jobs in `queued-research-jobs`): Does actual research — fetches real data from
FEC, SEC EDGAR, USASpending, and LDA lobbying databases via the existing
fetchers, then runs `analyzeEntity()` to produce actual findings (new facts,
elevated claims, evidence gaps, public records to check, significance). Returns
`mode: 'research'` with structured findings. The UI renders a `FindingsPanel`
showing real discovered facts with confidence tiers, source summaries, evidence
gaps, and records to check.

**Review mode** (contradictions, flagged facts, other queue types): Runs
`investigateQueueItem()` for editorial evaluation — is the contradiction
genuine, is the fact verifiable, etc. Returns `mode: 'review'` with
verdict/concerns/suggested edits. The UI renders a `ReviewPanel`.

Both modes resolve entity metadata (name, type, role) from the queue item's
entity slug or entity_id via `lookupEntityBySlug` / `lookupEntityById` in
`goblinhouse-api.ts`.

## System Architecture
The application is a full-stack, server-rendered monorepo built with Node.js 24 and Express 5, using pnpm workspaces. It generates HTML server-side and uses vanilla CSS, without frontend frameworks.

**UI/UX Decisions:**
- Design is inspired by ProPublica, featuring dark mode, serif typography, ample whitespace, and a restrained color palette with red, teal, and blue accents.
- A central logo (`/goblin-logo.png`) is used across all navigation.
- Entity profiles incorporate inline D3.js mini-graphs for connection visualization.
- Public and admin pages utilize distinct layout shells.
- Public features include a paginated entity directory, a threat assessment page, a broadcast player, a D3.js force-directed connection graph, a Claims Explorer, and a public Corrections Log.
- Admins review pending corrections at `/admin/corrections` (auth-gated).

**Technical Implementations:**
- **Database:** PostgreSQL with Drizzle ORM.
- **Authentication:** `express-session` with password-based authentication.
- **Build Tool:** esbuild.
- **AI Agent:** Uses `claude-sonnet-4-20250514` for research, fact extraction, verification, synthesis, and threat assessment. Features specialized AI personas (Goblins) and an LLM router for multi-provider fallback (Claude, Gemini, DeepSeek, Ollama).
- **Social Media (Crinkle):** Automated generation of shareable posts with a `draft → approved → posted` workflow and RSS 2.0 feed.
- **News Desk (Crinkle):** Autonomous AI newscaster synthesizing findings into broadcast-style news episodes using Claude for scripts and OpenAI TTS for audio.
- **Deduplication:** Comprehensive entity, connection, and fact deduplication mechanisms.
- **Pipeline Integrity Rules:** Strict rules govern fact generation, sourcing, retraction, and entity assignment.
- **Contradiction Engine:** Cross-entity pattern detection system with severity scoring.
- **Elected Officials Pipeline:** Distinct entity type with structured data, specialized forms, ingestion of voting records, and Claude-powered contradiction detection.
- **Market Intelligence Pipeline:** Automated stock price tracking and signal detection.
- **Oversight Agent:** Daily AI-generated system health briefings from Claude.
- **Per-Goblin Budget Controls:** Daily cost caps enforced before API calls.
- **Queue Management (`/admin/research`):** Admin interface for job queue management.
- **Book (`/book`):** Chapter-based reader for "The Architecture of Secrecy" with TOC, per-chapter reading view, and entity cross-referencing.
- **Findings (`/findings`):** Consolidated findings page with "Conflicts of Interest" and "Threat Assessment" views.
- **Congressional Capture Portal (`/congress`):** Interactive portal tracking elected officials with capture risk scoring, individual profiles, state-by-state views, donor interest mapping, and silence detection.
- **Silence Detection:** Automated detection of topics where officials receive donor funding but maintain no public record.
- **Batch Contradiction Analysis:** Admin-only UI for triggering batch contradiction analysis via SSE with real-time progress.
- **Preparedness & Risk Perception Analysis (`/preparedness`):** Analytical framework mapping public advocacy vs private preparation.
- **Data Quality Tools (`/admin/data-quality`):** Admin dashboard with utilities for data integrity, including display-layer deduplication for facts and connections, and a reclassification gate for fact tiers.
- **SEO / Search Engine Indexing:** Dynamic `sitemap.xml`, `robots.txt`, and server-rendered HTML with proper meta tags.
- **Homepage Stats:** Displays key metrics like entities investigated, documented facts, and mapped connections.
- **Attribution Status System:** Facts are categorized as `confirmed`, `disputed`, or `unreviewed`.
- **Tiered Entity Page Facts:** Entity pages display facts in priority tiers with confidence badges and data freshness indicators.
- **Investigation Handoff Tool (`/admin/inferences/handoff/:id`):** Admin tool to export inferential claims as structured prompts for external LLMs.
- **Entity Disambiguation Gate:** Pipeline-level validation of search results against target entities.
- **Investigation Emission Layer (`/admin/emissions`):** Self-perpetuating investigation loop emitting child investigations based on credibility and significance.
- **Pipeline Quality Controls:** Zero-result validation, fact deduplication, and absence-of-evidence reasoning filters.
- **Jurisdiction-Aware Search:** Entities have `primary_jurisdiction` and `nationality` fields, influencing synthesis and conflict detection.
- **Anti-Scraping Countermeasures:** Detection-only on this host — zero-width Unicode session watermarks (placed between elements, never inside quotable text), hidden crawler trap links, rate-limit tripwires, and an admin detection panel. A trap hit is logged and handed off (302, noindex) to the maze at sixoxis.goblinhouse.net, which owns containment and fingerprinting. Goblin House serves no fabricated content under its own domain.
- **Donation-Funded Research (`/research/funded/:factId`):** Inferential claims on entity pages display "Fund Research" buttons linking to Stripe, triggering deep research jobs and awarding collectible Goblin Cards.
- **Goblin Card Collectibles (`/cards`):** 12 collectible cards themed after investigative goblins, awarded with weighted rarity rolls after funded research donations.
- **Visitor Analytics (`/admin/analytics`):** Lightweight in-house traffic log for the public site, recording non-admin GET requests with hashed IPs for privacy.
- **Closed Loop Monitoring (`/closed-loops`):** Dashboard tracking documented self-reinforcing power structures with components, confidence levels, and evidence.
- **Entity Handoff Orchestrator:** Per-entity unified pipeline that fans out to every enrichment stage and writes a persistent ledger.
- **Closed-Loop Auto-Populator:** Nightly scan of entity facts + connections that proposes new dossiers via keyword-based component extractors.
- **Public JSON API (`/api/*`):** Read-only endpoints for approved consumers, with CORS and caching headers. Includes endpoints for entities, nonAQ claims, and studies.
- **Handoff Framework:** A descriptor and lifecycle layer for external LLM clients to introspect and submit various handoffs (e.g., contradictions, social posts, FOIA requests) via a uniform API. This includes 24 tailored handoffs across different investigative categories.
- **Cross-Cluster Name Scan:** A project-wide cross-reference job that scans source content for mentions of entities in other clusters, emitting structured reports and facts.
- **Thin-source sweep:** A platform-wide tool for repairing thin or empty source content by re-fetching and backfilling document text, using a robust fallback fetcher (e.g., Wayback Machine, govinfo.gov).
- **Merge-aware pipeline ledger + stuck-stage watchdog:** Ensures the `entity_pipeline_state` ledger correctly merges new pipeline probe results without overwriting valuable data and automatically flags and retries stuck or failed pipeline stages.

**Sister Site: `seealiens.net` (`artifacts/seealiens`)**
A second public-facing website consuming the Goblin House Public JSON API. It is an SSR Express 5 server with a Vite/React admin SPA. Features include:
- **Public routes:** `/`, `/nonaq` (+ `/nonaq/:slug`), `/sightings`, `/signal`, `/machine`, `/blog/:slug`, `/about`, `/contact`, `/healthz`, and JSON endpoints for client-side search.
- **Public tip endpoint (`POST /seealiens/api/tip`):** Anonymous-write JSON endpoint, rate-limited, with honeypot field.
- **Telnyx webhooks (`POST /seealiens/webhooks/telnyx/{messaging,voice}`):** Mounted with `express.raw()` for signature verification, handling message and voicemail events.
- **Visual identity:** 90s-web starfield + UFO + rainbow-divider chrome.
- **Shared library:** `@workspace/shared-content` provides Zod schemas and a typed `goblinhouseClient`.
- **Database:** New `seealiens` PostgreSQL schema with tables for posts, nonaq drafts, studies, FOIA requests, prompt runs, and a unified messages inbox.
- **Admin layer (`/seealiens/admin`):** React + Vite SPA with single shared password authentication. Includes APIs for managing posts, nonaq entries (with publish to Goblin House), studies, prompt forge (for AI content generation with Anthropic, Gemini, DeepSeek support and rate limiting), and a unified inbox for messages. Editorial vocabulary for posts includes statuses and tags.

## CI / Validation Gates
- **`test` validation command** (registered via the validation system): runs `pnpm --filter @workspace/api-server test` on every `mark_task_complete` and blocks the merge if any test fails. The api-server suite includes `src/__tests__/patch-2.2-leak-regression.test.ts`, the Patch 2.2 publication-invariant regression test, which boots the Express app on an ephemeral port and asserts withdrawn finding text never appears on `/findings`, `/report`, `/feed`, `/claims-archive`, or any active `/goblin/:slug`. The test reads withdrawn rows from the live DB and falls back to inserting a sentinel withdrawn row if none exist, so it never silently no-ops on a fresh schema. The dev DB schema is kept current by `scripts/post-merge.sh` (which runs `pnpm --filter db push-force` after every merge), so the validation has a populated Postgres available.
- **`check-finding-reads` validation command** (registered via the validation system; also wired into the root `pnpm run typecheck` so it runs as part of the standard local check): a static gate, `scripts/src/check-finding-reads.ts`, that complements the runtime `patch-2.2-leak-regression.test.ts` by catching the same class of leak at write-time — before the route is ever shipped. It scans every public route file under `artifacts/api-server/src/routes/` for `from(findings)` (drizzle) and `FROM findings` (raw SQL) reads, and fails the build if any of them is missing the publication filter (`isPublishedFinding` for drizzle, or `review_status = 'published'` AND a non-empty `source_urls` check for raw SQL). Admin-only routers are auto-exempted by parsing `routes/index.ts` for `adminRouter.use(...)` mounts, and individual call sites can opt out with the line comment `// allow-unfiltered-findings: <reason>` placed in the comment block immediately above the offending line — currently used in `routes/findings.ts` for the editorial-review surface and the operator-only attach/remove-source POST handlers. The script's failure message points authors at the `isPublishedFinding` helper in `lib/db/src/schema/index.ts`.

- **Local-LLM tier moved off-Replit (Task #326, follow-up to #319).** When attempting to run real qwen2.5 models inside the `Local LLM (Ollama)` workflow we discovered each Replit workflow has an **8 GiB hard cgroup memory cap** (`/sys/fs/cgroup/memory.max = 8589934592`). The `ollama serve` process itself sits at ~2.8–3 GiB resident before any model loads, so even modest weights OOM: qwen2.5:14b q8_0 (15.7 GB), q5_K_M (9.8 GB), and qwen2.5:7b q5_K_M (~5.4 GB) were all OOM-killed at runner spawn. Conclusion: the in-container local tier is unusable for any model that produces meaningfully better output than `llama3.2:1b`. The chosen workaround is to run Ollama on the operator's own computer and expose it to the api-server via a **Cloudflare Quick Tunnel**: install `cloudflared` (`winget install --id Cloudflare.cloudflared` on Windows, `brew install cloudflared` on macOS), make sure `ollama serve` is running locally with whatever model the host's RAM/VRAM supports (M-series Macs comfortably run 14B Q8), then run `cloudflared tunnel --url http://localhost:11434 --http-host-header localhost`. **The `--http-host-header localhost` flag is mandatory** — without it, Ollama's built-in origin check returns an opaque `403` with empty body to any Host header that isn't `localhost`/`127.0.0.1`, and the adapter's health probe treats that as unreachable. Set `OLLAMA_HOST=https://<random-three-words>.trycloudflare.com` and `LOCAL_LLM_MODEL=<model name>` (e.g. `qwen2.5:14b-instruct-q8_0`) **as Replit Secrets, not as `[userenv.shared]` env vars** — the latter get committed to `.replit` and the tunnel hostname is bearer-equivalent (anyone who reads the file can hit the model). **Treat the tunnel hostname as bearer-equivalent**: it is publicly reachable with no auth, and any party who learns it can invoke the model and run up the operator's compute. The hostname is high-entropy enough to be hard to guess, but it should be rotated whenever the operator suspects exposure (and is rotated automatically whenever `cloudflared` restarts). **Auth lockdown (Task #327):** the adapter now attaches auth headers on every request (both the `/api/tags` health probe and the `/v1/chat/completions` call) when the corresponding Replit secrets are set. Two modes are supported and are additive — operators can use either or both. (1) **Cloudflare Access service token** (preferred, enforced at the edge before the tunnel): set `CF_ACCESS_CLIENT_ID` and `CF_ACCESS_CLIENT_SECRET`; the adapter sends them as `CF-Access-Client-Id` / `CF-Access-Client-Secret`. Configure a Zero-Trust Access application in front of the tunnel hostname and create a service-token policy that allows only that token. (2) **Shared bearer token** (for setups using a small caddy/nginx reverse proxy on the operator's machine that checks `Authorization: Bearer <token>` before forwarding to Ollama): set `OLLAMA_AUTH_TOKEN`. If neither secret is set the adapter degrades gracefully to the original unauthenticated behaviour (still functional, but the tunnel hostname is once again the only secret). Auth coverage is asserted by `src/__tests__/local-llm.test.ts` (one test stubs `globalThis.fetch` and verifies all three headers reach both endpoints; another verifies no auth headers are sent when env is empty so we don't regress operators still in degraded mode).

- **Manual Trigger + Router Smoke panels on `/admin/agent` (Task #333).** The agent control panel grew two operator surfaces and a credential-reality note. **Manual Trigger** renders one pill per job-type from a single source-of-truth catalogue (`src/lib/agent/job-types.ts`), grouped visually by routing tier — URGENT (claude only, for jobs that bypass `callLLM` and call `callClaudeWithWebSearch` directly: `research_entity`, `directed_inquiry`), HIGH (→ gemini → claude), NORMAL (→ deepseek → gemini → claude), LOW (→ local → deepseek → gemini → claude; currently empty, renders a "no jobs catalogued at this tier" placeholder) — so the operator can see at a glance which provider chain a fired job will hit. Each pill carries `data-jobtype`, `data-tier`, `data-requires-entity`, and `data-required-inputs` (JSON) attributes; client JS sets the hidden `jobType` AND `priority` (from `data-tier`) fields, prompts for any required aux inputs, and POSTs through the existing `/admin/research/run-job` route with `redirect=/admin/agent` so the operator stays on the agent page. The catalogue itself mirrors the `processor.ts:processJob` switch statement (21 entries). Drift between the catalogue and the dispatch table — or between catalogue tiers and `URGENT_JOBS` / `HIGH_REASONING_JOBS` / `NORMAL_EXTRACTION_JOBS` from `llm-types.ts` — is asserted by `src/__tests__/admin-agent-manual-trigger.test.ts`. **`/admin/research/run-job` was expanded** from a 2-case special-cased helper (synthesise + map_connections) to a validating gate: unknown `jobType` returns HTTP 400 with the rejected value plus the allowed list, `requiresEntity=true` jobs without `entityId` return 400, missing/whitespace-only `requiresInputs` fields return 400, **`priority` defaults to `spec.tier` from the catalogue but a visible "Force tier" dropdown in the panel lets the operator override it** (validated server-side against the 4-tier allowlist `{urgent, high, normal, low}` — anything outside the allowlist falls back to the catalogue default). This allows "un-stucking" the pipeline when a specific provider is down or hallucinating by forcing a job onto a different tier. **Router Smoke** renders the results of `checkCredentials()` (the 2s health probes used by the router for fallback logic) as status chips (green/red) next to each provider, so the operator can verify Replit Secrets are loaded and the Local Tunnel is up without tailing logs.

- **Multi-provider LLM router (`src/lib/agent/llm-router.ts`, Task #319).** Single `callLLM(prompt, systemPrompt?, options?)` entry point that routes between Claude, Gemini 2.5 Pro, DeepSeek V3, and a local Ollama model based on `(jobType, priority, requiresWebSearch)`, with automatic tier fallback. Adapters live next to the router: `gemini.ts` (raw `fetch` against `gemini-2.5-pro:generateContent`), `deepseek.ts` (OpenAI-compatible `deepseek-chat`), and `local-llm.ts` (Ollama's `/v1/chat/completions` with a 2-second `/api/tags` health probe so the router falls through fast when Ollama isn't running). All adapters share the contract in `llm-types.ts` and never throw on upstream errors — they return `{ ok: false, code, error }` so the router can advance to the next tier without a try/catch around every call. **Routing rules:** `requiresWebSearch || priority="urgent"` → Claude only (web-search needs Anthropic tool support); `priority="urgent"` OR jobType in `{research_entity, directed_inquiry}` → Claude only (these jobs invoke `callClaudeWithWebSearch` directly and bypass `callLLM`; Task #333 moved them out of the high-reasoning bucket and into the URGENT tier so the Manual Trigger panel labels them honestly); `priority="high"` OR jobType in `{synthesise, analyze_contradictions, detect_conflicts, investigate_inference, assess_threats}` → Gemini → Claude; `priority="normal"` OR jobType in `{extract_facts, ingest_public_data, map_connections, verify_fact, detect_silences, build_constituency_baseline}` → DeepSeek → Gemini → Claude; `priority="low"` → Ollama → DeepSeek → Gemini → Claude; default (no actionable hint) → Claude only (preserves legacy `callClaude` semantics for any caller that hasn't opted into routing). **Pricing:** Gemini 2.5 Pro $1.25 / $10 per million tokens, DeepSeek $0.27 / $1.10 per million tokens, local $0. Cost is computed per call by `computeCost()` in `llm-types.ts` and persisted alongside the new `provider` column on `goblin_cost_log` (nullable for backwards compat).

- **Merge-aware pipeline ledger + stuck-stage watchdog (Task #339).** The `entity_pipeline_state` ledger drives every operator-visible coverage chip on `/admin/pipeline-coverage` and the `/bunker*` cards, and it was getting wiped on every nightly `run_full_handoff` because `writeStageResult` did a blind upsert: the moment a fresh probe came back as `search_error` or `success` with `itemCount=0`, it overwrote a previously-confirmed `success` row with real `itemCount > 0`. Operators saw months of populated entities go red overnight. The fix has three parts. (1) **Merge-aware writeStageResult** in `src/lib/pipeline/orchestrator.ts` reads the existing row before deciding what to write. The decision is extracted into a pure function `isWorseThanPrior(prior, next)` (exported for testing): `prior.status="success" && prior.itemCount>0` is "protected" — any new probe whose status isn't success-with-itemCount-≥-prior is treated as worse and the prior row is preserved (only `attempts`, `lastRunAt`, and `lastQueuedAt` are bumped, and the new probe is recorded into the new `last_probe` jsonb column for forensic visibility). When the new probe is genuinely better-or-equal it overwrites everything AND clears `last_probe`. The `last_probe` column was added to `lib/db/src/schema/index.ts` and pushed via `pnpm --filter @workspace/db run push` (nullable jsonb, so existing rows tolerate it). (2) **Stuck-stage watchdog** `unstuckRunningStages({ olderThanMs?: number })` (default 24h) flips any `status="running"` row whose `last_run_at` is older than the threshold to `status="failed"`, appending `' | watchdog_unstuck stuck-running >Nh'` to the existing error column. Runs in two places: at the top of every nightly `tick()` BEFORE `backfillCoverage`, and once at the top of `startScheduler()` boot path (so an api-server restart immediately cleans any rows that the previous process abandoned mid-stage). On the first boot after this task merged, **2,322 rows** were unstuck this way (verified: `SELECT count(*) FROM entity_pipeline_state WHERE error LIKE '%watchdog_unstuck%'`). (3) **Manual re-queue surface** added to `/admin/pipeline-coverage` for operators to force-clear a stuck or "worse" state.

- **Bukimi no tani / `/bunker*` archived (April 2026).** The "Bukimi no tani" public-facing bunker tracker (proof-of-concept location/cluster/migration views over the curated `BUNKER_TRACKER` dataset) is hidden from the public site. The nav entry and footer entry were removed from `src/lib/views.ts`, and the `router.use(bunkerRouter)` mount in `src/routes/index.ts` is commented out — `/bunker`, `/bunker/clusters`, `/bunker/migrations`, `/bunker/network`, `/bunker/data.json`, and the legacy `/aliens*` redirects all return 404 on the public site. The route file `src/routes/bunker.ts`, the dataset `src/data/bunker-tracker.ts`, and the route-level test `src/routes/bunker.test.ts` are intentionally kept on disk so the test suite continues to exercise them in isolation (the test mounts `bunkerRouter` directly into a throwaway express app) and the feature can be brought back by uncommenting the import and mount in `src/routes/index.ts` and re-adding the two link entries in `src/lib/views.ts`.

- **Money-flow tracer + Shadow Ledger (May 2026).** Two new additive surfaces for following the documented dollar trail behind a closed-loop dossier.
  - **Schema (additive only):** six new tables in `lib/db/src/schema/index.ts` after the closedLoops block — `money_flow_chains` (one row per chain, polymorphic source_ref), `money_flow_hops` (one row per hop, unique on `(chain_id, ordinal)`), `money_flow_vanish_points` (one row per hop with a typed reason — see `VANISH_REASONS` in `artifacts/api-server/src/lib/money-flow/types.ts`: `shell_company` | `offshore_jurisdiction` | `private_equity_holding` | `cash_withdrawal` | `cryptocurrency_address` | `undisclosed_beneficial_owner` | `disclosure_not_filed` | `foreign_jurisdiction_no_reciprocal_disclosure` | `attorney_client_privilege` | `trust_with_unnamed_beneficiary` | `other_with_note`; unique on `hop_id`, note required), plus the Shadow-Ledger trio `trigger_events` (FK closed_loop, with `proximity` and `policy_influence` curator columns), `public_cost_lines` (typed cost lines), `closed_loop_money_flow_chains` (m:n join, `role` ∈ profit_mechanism | funding_source | supporting_context, unique on `(closed_loop_id, chain_id)`).
  - **Domain helpers:** `artifacts/api-server/src/lib/money-flow/{types,queries,validate,populate}.ts` and `artifacts/api-server/src/lib/shadow-ledger/score.ts`. `validateChain` distinguishes hard errors (block save) from soft warnings (monotonic time, conservation-of-amount with 5% slack). `computeOrchestrationScore` is pure: `score = clamp((financial × proximity × policy_influence) ÷ public_cost × vanish_penalty, 0, 1)` with log-scaled dollar inputs (saturate at $1B), categorical proximity/policy enums, and a `[0.5, 1.0]` vanish penalty floor; every input is named and the breakdown is rendered inline on every public dossier page.
  - **Routes:** admin tracer at `/admin/money-flow` and `/admin/money-flow/:id` (`requireAuth` gated, full CRUD, populator button). Public tracer at `/money-flow/:id` and `/shadow-ledger` index + `/shadow-ledger/:loopId` detail; both gated by `status='active'` so nothing leaks before review.
  - **Populator:** `runMoneyFlowPopulator()` walks `donor_interests`, `funded_research`, and `market_signals` and seeds *proposed* single-hop chains keyed by deterministic `provenance.seedKey` (re-runs are idempotent). Trigger events are seeded from `closed_loops.components` for dossiers with no `trigger_events` row. The populator never auto-promotes and never auto-links chains to dossiers.
  - **Shadow-ledger admin panels:** the `/admin/closed-loops/preview/:loopId` page now hosts three CRUD panels under the existing draft-finding panel — Trigger events (typed event with `proximity` + `policy_influence`), Public-cost lines (typed cost with optional dollar amount + qualitative description), and Money-flow chains (m:n picker that links existing chain ids; uniqueness enforced by `clmfc_loop_chain_uniq`). All POSTs validate against the typed enums in `lib/money-flow/types.ts` (`TRIGGER_EVENT_TYPES`, `TRIGGER_PROXIMITIES`, `PUBLIC_COST_TYPES`, `CHAIN_LINK_ROLES`, plus the score-side `POLICY_INFLUENCE_OPTIONS = none | adjacent | advocate | vote | sponsor`) and scope deletes by `closed_loop_id` so URL tampering can't cross loops.
  - **Predictive-alert hook:** `lib/shadow-ledger/predictive.ts` (`scanPredictiveAlerts({sinceDays, limit})`) is a read-only scan that lights up active dossiers whose anchor entity received a fresh `donor_interests` / `market_signals` / `funded_research` row in the last N days (default 14, max 365). Eligible dossiers must be `status='active'` AND have ≥1 trigger event filed — never lights up half-loaded loops. Surfaced at `/admin/shadow-ledger/predictive`. Curator-prompting only; nothing auto-publishes.
  - **Tests:** `src/__tests__/{shadow-ledger-score,money-flow-validate,money-flow-summarise,money-flow-routes,money-flow-bulk-routes}.test.ts` cover the formula edge cases, validator error/warning split, summary rendering, route gating, and bulk-classify endpoints.
  - **Curator guide:** `artifacts/api-server/src/lib/money-flow/README.md` documents the vanish-point and mechanism taxonomies and the score formula in full.

## External Dependencies
- **AI:** Anthropic Claude (`claude-sonnet-4-20250514`), OpenAI TTS, Google Gemini (`gemini-2.0-flash`, `gemini-2.5-pro`), DeepSeek (`deepseek-chat`), local Ollama (`llama3.2:1b` default).
- **Database:** PostgreSQL.
- **ORM:** Drizzle ORM.
- **Session Management:** `express-session`.
- **Fonts:** Inter, Source Serif 4, JetBrains Mono.
- **Public APIs:** ProPublica Nonprofit Explorer API, Congress.gov API, ProPublica Congress API, Yahoo Finance, Wayback Machine, Wikipedia/Wikimedia API, Clearbit Logo API, Telnyx.
- **Payment Processing:** Stripe.
## Crinkle's motion (broadcast player)

Crinkle on `/news` and `/studio` is two layers cut from one plate
(`public/crinkle-set.webp`, `public/crinkle-figure.webp`; regenerate with
`artifacts/api-server/scripts/split-crinkle-plate.py`). The figure is moved by
`RigDriver` in `public/broadcast-player.js` from `public/crinkle-rigs.json`:
integer plate-pixel offsets per frame with roles idle / talk / cue, baked by
`scripts/bake-crinkle-rigs.mjs` from gamescope federation rigs (VTube Studio
Live2D motions, study-only donor rhythm — no donor pixels ship). The bundle is
committed because the Railway build cannot see the rig corpus; rebake with
`node scripts/bake-crinkle-rigs.mjs --rigs <path to rigs/>` and bump the
`?v=` on `/crinkle-rigs.json` in `broadcast-player.js`.

## Silence flags and provenance (2026-09-26)

A silence flag (`silence_flags`) carries `confidence` = the strongest
confidence among the `donor_interests` rows behind it. Only `primary` and
`secondary` flags count toward the capture score, the scorecard, the
disclosure-gap wall or the public `/silences` desk (`SILENCE_DOCUMENTED_WHERE`
in `lib/silence-matching.ts`); `inferential` flags — the party-and-state
seed templates in `populate-donor-silences.ts` and LLM mappings — are shown
to operators only, labelled. `days_silent` is measured from `floor_date`
(earliest recorded floor vote on a related bill, any official), never from
when a row was inserted; NULL means no dated bill. The detector marks a flag
`addressed` itself when a statement or vote on the topic turns up. Bill ids
are compared through `normalizeBillId()` (`lib/bill-ids.ts`); keywords match
whole words. Vote ingest needs `CONGRESS_GOV_API_KEY` on Railway — without it
the DEMO_KEY rate limit fails every bioguide lookup.

Object storage is R2 (`lib/storage/objects.ts`): public bucket for media,
`R2_PRIVATE_BUCKET_NAME` for database backups (never the public one).

## Running it locally (2026-09-26)

No Docker, no installer. From `artifacts/api-server`:

```
pnpm db:local:init      # first time: embedded Postgres in .local/pg + drizzle schema
pnpm db:local           # every other time; Ctrl+C stops it
pnpm local              # build + the whole platform on :3000 against it
```

`pnpm db:snapshot` (with `PROD_DATABASE_URL` set to Railway's
`DATABASE_PUBLIC_URL`) copies production into the local database, minus
visit and scraper logs. `.env.local` is the only config; its `DATABASE_URL`
names the local cluster's user, password, port and database.

The operator workspace runs as its own role: `pnpm admin` starts
`WORKER_ROLE=admin` on :3010 — `/admin` only, no migrations, seeds, backfills,
agent or scheduler — against `ADMIN_DATABASE_URL` (production) if set. Xixoxis
launches it as "Goblin House Admin". With that in place, `ADMIN_DISABLED=1` on
the Railway service removes `/admin` and both password logins from the public
host; `/api/v1` bearer access (Goblin Brain) is unaffected.

## The roll-call record (2026-09-26)

`lib/congress/` holds the complete Senate and House roll-call record from
the primary feeds (senate.gov LIS XML, clerk.house.gov EVS XML) and the
member roster + committee seats from unitedstates/congress-legislators:
tables `congress_members`, `congress_committees`, `congress_committee_members`,
`roll_calls`, `roll_call_votes`, `congress_member_stats`. Ingest is
incremental and idempotent (keyed by chamber/congress/session/roll number);
`party_positions` on each roll call is each party's yea/nay majority, and a
member's party unity / breaks / attendance are recomputed into
`congress_member_stats` after every ingest. `voting_records` is the legacy
projection every older reader uses; new readers use the record directly.

Automation: the nightly scheduler runs `runRollCallIngest()` (this year's
House, this session's Senate, roster weekly); boot runs the resumable
`ensureRollCallBackfill()` for 2023..now with progress in `scheduler_state`
(`rollcall_backfill_<year>`, delete a key to force a re-run). Manual:
`pnpm votes:backfill -- --from 2023 --to 2026`. The `/votes` desk shows
coverage and last-run time so a stalled feed is visible to a human.

## Member funding from the FEC (2026-09-26)

`lib/fec/` fetches each current member's principal campaign committee from
api.open.fec.gov (`FEC_API_KEY`): receipt totals per two-year cycle, every
PAC contribution (Form 3 line 11C), and the FEC's employer roll-up of
individual money — tables `fec_committees`, `fec_committee_totals`,
`fec_pac_receipts`, `fec_employer_totals`, `fec_member_sectors`. Sectors
come from `lib/fec/sectors.ts`, an ordered, tested list of name patterns;
the rule that fired is stored on each row. A PAC giving ≥ $5,000 in a cycle
becomes an entity (`fec-<committee id>`), a documented primary `donor`
connection and a `donor_interests` row with confidence `primary` — the rows
silence detection and the capture score count. The pace is ~50 requests a
minute, so the nightly refreshes 60 members (oldest first) and boot runs a
resumable backfill; `pnpm fec:funding -- --bioguide X` does one by hand.
The `/votes/:slug` page shows the money next to the votes.

## Measures, tickers and the trade crosses (2026-09-26)

`lib/congress/bills.ts` enriches every measure that reached a roll call
from govinfo BILLSTATUS (no key): title, policy area, subjects, sponsor,
cosponsors, committees → `bills`, `bill_cosponsors`. `lib/trades/tickers.ts`
names every traded ticker from the SEC company list and SIC codes →
`ticker_companies`, sector via the same classifier as the FEC money.
`lib/trades/crosses.ts` recomputes `member_trade_flags` and
`congress_member_trade_stats`: a trade is flagged `oversight` (sector a
member's committee oversees — `COMMITTEE_SECTORS` in `lib/trades/maps.ts`),
`vote_window` (a yea/nay on a measure in that sector within 30 days —
`POLICY_AREA_SECTORS`), or `donor_sector` (≥ $10k PAC money in that sector).
Nightly after the PTR ingest; boot one-shot for the first load
(`trade_context_backfill_status`). `pnpm trades:context` runs it by hand.
Only House PTRs are parsed today; Senate EFD is the open gap.

## Senate disclosures and the Congressional Record (2026-09-26)

`lib/trades/senate-efd.ts` reads Senate periodic transaction reports from
efdsearch.senate.gov (agreement cookie → DataTables listing → HTML report
tables) into the same `congressional_ptr_filings` / `_transactions` tables
as the House, `chamber = 'senate'`, `source = 'senate-efd'`; scanned
"paper" reports are indexed with `tx_parse_status = 'paper'`. Nightly since
90 days; boot backfill since 2023 (`senate_efd_backfill_status`).

`lib/congress/floor.ts` splits Congressional Record granules (govinfo API)
into speeches (`floor_statements`, cursor in `floor_days`), resolves the
speaker through the roster, tags sectors and bill references; the silence
detector counts a floor speech as a statement, and `/votes/:slug` shows
"Said, then voted" pairs. The API allows 10 requests on DEMO_KEY: set
`GOVINFO_API_KEY` (a free api.data.gov key; `CONGRESS_GOV_API_KEY` is the
same key) on Railway or the backfill sits at "waiting for GOVINFO_API_KEY".
`pnpm record:senate` / `pnpm record:floor -- --day YYYY-MM-DD` by hand.

## Knowledge: the platform describing itself (2026-09-26)

`lib/knowledge/desks.ts` is the registry of public desks (what, how,
sources, live facts); `lib/knowledge/systems.ts` the pipelines (code,
tables, cadence, scheduler_state keys, gotchas); `docs/knowledge/sessions/`
the field notes per coding session. Served by `/api/crinkle/context?path=`
(the wire widget opens with "On this page — …" from it; no LLM) and
`/api/v1/knowledge` (Goblin Brain absorbs it as lore for the app
"goblinhouse"; `server/fetchers/goblinhouse.js` in the Brain). Crinkle's
broadcast prompt gets `platformKnowledgeDigest()` appended so scripts cite
desks as they describe themselves. When you build a desk or a pipeline,
add it to the registry and write the session note — that is how the next
session, the Brain and Crinkle learn it.

## PAC profiles and money between members (2026-09-26)

Every committee that contributes to a member's principal committee is
profiled from the FEC's `/committees/` endpoint into `fec_pac_profiles`
(designation, committee type, organisation type, connected organisation,
sponsor). Sectors are classified profile-first (`classifyCommittee` in
`lib/fec/sectors.ts`): designation D is a leadership PAC, X/Y party, org
type L labor; only then do the name rules run, on the PAC name and then its
connected organisation. Name rules are compiled plural-tolerant. A leadership
PAC's sponsor resolves to a bioguide id, so `/votes/<member>` shows "Money
between members" in both directions. `lib/fec/profiles.ts` runs nightly after
the funding slice and as a resumable boot backfill; `pnpm fec:profiles`.

## Every measure (2026-09-26)

`lib/congress/bills-bulk.ts` keeps `bills` / `bill_cosponsors` current for
the whole current and previous Congress from govinfo's bulk JSON listing
(`/bulkdata/json/BILLSTATUS/<congress>/<type>`), fetching only files whose
last-modified time is newer than `bills.source_modified`. Nightly with a
20-minute budget after the voted-measures pass; resumable boot backfill;
`pnpm bills:sync`. Sponsoring or cosponsoring a bill on a topic counts as
being on the record for the silence detector, and `/votes/<member>` shows
"What they put their name to" including the cross-party cosponsorship share.
