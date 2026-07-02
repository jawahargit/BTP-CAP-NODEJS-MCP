Project Setup Guide

## What This Project Is

A SAP BTP CAP (Cloud Application Programming) Node.js application with Fiori Elements UI for managing Business Partners. It exposes an OData V4 service with a List Report + Object Page UI, role-based access control, and draft-enabled create/edit flow.

---

## Project Structure

```
bp-cap-fiori/
│
├── db/
│   ├── schema.cds                              ← All entities (BusinessPartners, Addresses, Roles, Tax, CodeLists)
│   ├── dev.sqlite                              ← Local dev DB file (gitignored, auto-created — see below)
│   └── data/
│       ├── com.bp.manager-BPCategories.csv     ← Seed: Person / Organisation / Group
│       ├── com.bp.manager-BPStatuses.csv       ← Seed: ACTIVE / BLOCKED
│       └── com.bp.manager-BusinessPartners.csv ← 9 sample Business Partners
│
├── srv/
│   ├── bp-service.cds   ← Service definition, projections, @restrict, actions
│   ├── annotations.cds  ← All Fiori Elements annotations (List Report + Object Page)
│   ├── mcp.cds          ← MCP (AI agent) annotations — @gavdi/cap-mcp
│   ├── bp-service.js    ← Node.js handler (BEFORE/AFTER/ON hooks)
│   └── server.js        ← /health endpoint for CF health-check
│
├── app/
│   └── bp-manager/
│       ├── xs-app.json  ← Approuter routing
│       └── webapp/
│           ├── manifest.json          ← Fiori app descriptor (List Report → Object Page routing)
│           └── i18n/i18n.properties   ← All UI text labels
│
├── package.json       ← CAP deps + mocked auth config for local dev
├── xs-security.json   ← XSUAA scopes + 3 role templates
├── mta.yaml           ← CF deploy: approuter + srv + db-deployer + services
├── .nvmrc             ← Pins Node LTS via nvm (scoped to this project only)
└── CLAUDE.md          ← This file
```

---

## Steps Completed

### Step 1 — Unzip Source Files
Extracted `bp_cap_mcp.zip` into the project root. All 11 files landed flat in the root directory.

```
schema.cds, bp-service.cds, annotations.cds, bp-service.js, server.js,
manifest.json, i18n.properties, xs-app.json, package.json, xs-security.json, mta.yaml
```

### Step 2 — Reorganize into CAP Folder Structure
Moved each file into its correct location per CAP conventions:

| From (root) | To |
|---|---|
| `schema.cds` | `db/schema.cds` |
| `bp-service.cds` | `srv/bp-service.cds` |
| `annotations.cds` | `srv/annotations.cds` |
| `bp-service.js` | `srv/bp-service.js` |
| `server.js` | `srv/server.js` |
| `manifest.json` | `app/bp-manager/webapp/manifest.json` |
| `i18n.properties` | `app/bp-manager/webapp/i18n/i18n.properties` |
| `xs-app.json` | `app/bp-manager/xs-app.json` |
| `package.json` | *(root — unchanged)* |
| `xs-security.json` | *(root — unchanged)* |
| `mta.yaml` | *(root — unchanged)* |

### Step 3 — Create CSV Seed Data
Created `db/data/` with three CSV files loaded by `cds deploy` the first time `db/dev.sqlite` is created:

- **BPCategories**: `1=Person`, `2=Organisation`, `3=Group`
- **BPStatuses**: `ACTIVE`, `BLOCKED`
- **BusinessPartners**: 9 sample records (mix of persons, orgs, groups; 2 blocked)

### Step 4 — Fix npm Dependencies (CDS 7 → 8)
Updated `package.json` to resolve deprecation warnings and engine mismatch:

```json
"dependencies": {
  "@sap/cds": "^8.0.0"       // was ^7.9.0 (deprecated)
},
"devDependencies": {
  "@sap/cds-dk": "^8.0.0",   // was ^7.9.0 (deprecated)
  "@sap/ux-specification": "~1.120.0"  // was ^1.120.0 — pinned to avoid 1.144+ which requires Node 22
}
```

Then ran `npm install` — vulnerabilities dropped from 41 to 18.

> **Note:** Node v20.9.0 is in use. Upgrade to v20.17.0+ to clear the remaining engine warning:
> ```bash
> nvm install 20 && nvm use 20
> ```

### Step 5 — Fix CDS 8 Import Syntax for `sap.common`
In CDS 8, `sap.common` is a **context** inside `@sap/cds/common` and cannot be imported with the namespace syntax. Two fixes were applied in `db/schema.cds`:

**Import fix:**
```cds
// Before (CDS 7 style — broken in CDS 8)
using { cuid, managed, sap.common } from '@sap/cds/common';

// After (CDS 8 correct style)
using { cuid, managed, Country, sap.common.CodeList } from '@sap/cds/common';
```

**Entity fix:**
```cds
// Before
entity BPCategories : sap.common.CodeList { ... }
entity BPStatuses   : sap.common.CodeList { ... }
country : sap.common.Country;

// After
entity BPCategories : CodeList { ... }
entity BPStatuses   : CodeList { ... }
country : Country;
```

### Step 6 — Server Running
`cds watch` (via `npm run dev`) starts successfully:

```
[cds] - serving BPService { impl: 'srv/bp-service.js', path: '/api/v1/bp' }
[cds] - server listening on { url: 'http://localhost:4004' }
```

All tables created in `db/dev.sqlite`, all CSV seed data loaded.

### Step 7 — Persistent Dev Database

Switched the dev DB from `:memory:` to a file at `db/dev.sqlite`, because in-memory SQLite resets on every `cds watch` restart (which happens automatically on every file save) — wiping out any Block/Unblock changes made through the UI mid-session.

`cds watch` doesn't auto-seed a file-based DB the way it does `:memory:`, so `package.json` gained a `predev` hook that runs before `npm run dev`:

```json
"predev": "test -f db/dev.sqlite || npx cds deploy",
"dev":    "cds watch"
```

This deploys the schema and loads the CSVs **only if `db/dev.sqlite` doesn't exist yet** — a fresh clone works out of the box, and an existing local DB (with your test data) is left untouched on every subsequent restart.

`db/dev.sqlite*` is gitignored (covers the `-wal`/`-shm` sidecar files SQLite creates too) — it's never committed. To reset to pristine seed data: `rm -f db/dev.sqlite* && npm run dev`.

### Step 8 — Fix Block/Unblock Actions

`blockBP`/`unblockBP` were originally declared at the service level in `bp-service.cds`, which CDS compiles as *unbound* actions (`ActionImport`s with no entity key context) — the Object Page buttons couldn't target a specific record. Moved them inside `BusinessPartners`' `actions { }` block so they compile as bound actions (`IsBound="true"`).

Two follow-on issues, both fixed:

- **Draft context**: invoking the action while a record is being edited (`IsActiveEntity=false`) routed to the `BusinessPartners.drafts` shadow entity, which had no handler (`501`). The handler is now registered for `[BusinessPartners, BusinessPartners.drafts]`, always updates the persisted active row, and mirrors the change into the draft (including the drafts table's materialized `statusCode`/`statusName` columns, which are flat copies, not a live view) so the edit-mode form reflects the new value immediately and a later Save doesn't revert it.
- **Stale UI annotation**: `annotations.cds` still referenced the action as `BPService.EntityContainer/BusinessPartners_blockBP` (the unbound `ActionImport` path) after the action became bound. UI5 fails this silently client-side (`Unknown action import`) — the button looks clickable but no OData request ever fires. Fixed to the plain bound-action qualified name: `BPService.blockBP`.

Also added `@Common.SideEffects: { TargetEntities: ['_it'] }` on both actions so a Fiori client refetches the whole BP (incl. the virtual `statusCriticality`) after a successful call, instead of showing stale cached values.

### Step 9 — Add MCP Server (AI Agent Access)

Integrated [`@gavdi/cap-mcp`](https://github.com/gavdilabs/cap-mcp-plugin) so MCP-compatible AI agents (e.g. Claude Desktop) can query and act on Business Partner data. Exposed at `http://localhost:4004/mcp` (health at `/mcp/health`), configured via `cds.mcp` in `package.json` with `auth: "inherit"` — MCP requests authenticate the same way OData requests do and inherit the exact same `@restrict` role checks (a role with no grant for a tool never even sees it in `tools/list`).

`@mcp` annotations live in a new dedicated file, `srv/mcp.cds`, mirroring how `annotations.cds` isolates `@UI` concerns from the service definition:

- `BusinessPartners` → resource template with OData query support (`filter`/`orderby`/`select`/`top`/`skip`/`expand`) plus `query`/`get` wrapper tools. Deliberately **not** wrapped for create/update — it's draft-enabled with a multi-step Fiori edit flow that a raw MCP tool call can't safely replicate.
- `BPCategories`/`BPStatuses` → small static resources for resolving coded values.
- `blockBP`/`unblockBP` → tools with `elicit: ['confirm']`, so the plugin requires the calling client to support confirmation before executing a state-changing action.
- `getBPSummary` → read-only tool.
- Field-level `@mcp.hint` annotations explain coded values (`categoryCode` 1/2/3, `statusCode` ACTIVE/BLOCKED) an LLM can't infer from the field name alone.

**This plugin requires CDS 9 and Express 5**, which cascaded into a real upgrade chain: `@sap/cds` 8→9, `express` 4→5, `@sap/xssec` 3→4, `@cap-js/sqlite` 1→2 (the 1.x line's `@cap-js/db-service` peer-caps `@sap/cds` at `<9`), `eslint` 8→10. Two genuine breaking changes surfaced and were fixed, not worked around:

1. **`@sap/cds-fiori@1.x` breaks under Express 5** — it builds Fiori-preview mock routes with a bare `'*'` wildcard, which Express 5's stricter `path-to-regexp` rejects at server startup (`PathError: Missing parameter name`). Fixed by bumping to `@sap/cds-fiori@^2.3.0`, which detects the Express major version and uses `*splat` instead.
2. **The persisted `db/dev.sqlite` went schema-stale** — CDS 9 added a `DraftMessages` column to the internal `DraftAdministrativeData` draft table. A DB file deployed under CDS 8 fails every draft operation with `no such column: DraftMessages` until redeployed against the current model: `rm -f db/dev.sqlite* && npx cds deploy`. **Do this after any major `@sap/cds` version bump.**

The newer native `better-sqlite3` (pulled in by `@cap-js/sqlite@2.x`) also needed a current Node — the system Node here was too old to have a prebuilt binary, and source-compiling failed (`node-gyp` needs Python's `distutils`, removed in 3.12+). Rather than upgrade the system-wide Node (would affect every other project on the machine) or patch the system Python, installed `nvm` and pinned a Node LTS via `.nvmrc`, scoped to this project only:

```bash
nvm install   # reads .nvmrc
nvm use
```

### Step 10 — Verify MCP with the Claude Code CLI

Registered the local server and confirmed it end-to-end with a real Claude Code process (not just curl):

```bash
claude mcp add --transport http bp-manager http://localhost:4004/mcp \
  --header "Authorization: Basic $(echo -n 'admin@test.com:x' | base64)"
claude mcp get bp-manager   # should show Status: ✔ Connected
```

A newly-registered server isn't hot-loaded into an already-running Claude Code session — tool discovery happens at session start. Verified with a fresh headless process instead:

```bash
claude -p "Using the bp-manager MCP server, get the Business Partner summary counts." \
  --allowedTools "mcp__bp-manager__get-bp-summary"
```

Returned correct real data (9 total, 2 blocked, matching the seed data). Headless runs need `--allowedTools` listing exact `mcp__<server>__<tool>` names to get non-interactive permission approval.

This also confirmed the `elicit: ['confirm']` safety gate works with a real client, not just curl: headless mode has no way to show an interactive confirmation dialog, so calling `block-business-partner` via `-p` correctly **declined and did not execute** — verified against the actual server state (`isBlocked: false` unchanged) rather than just trusting the reported outcome. To actually run a write tool through Claude Code, use an interactive `claude` session where the confirmation prompt can be approved.

**Full verification results:**

| Test | Result |
|---|---|
| Registration (`claude mcp add`) | Connected |
| Tool discovery | All 6 tools found: `cap_describe_model`, `block-business-partner`, `unblock-business-partner`, `BPService_BusinessPartners_query`, `BPService_BusinessPartners_get`, `get-bp-summary` |
| `get-bp-summary` | Correct data: 9 total, 7 active, 2 blocked, 4 persons, 4 orgs |
| `BPService_BusinessPartners_query` (filtered) | Correctly returned the 2 known blocked BPs (Jane Smith, Apex Innovations) |
| `elicit: ['confirm']` safety gate | Headless mode correctly declined to execute `block-business-partner` without an interactive confirmation prompt — verified against actual server state (still `ACTIVE`/`isBlocked: false`), not just trusted from the report |

---

## Running Locally

```bash
npm install
npm run dev        # auto-provisions db/dev.sqlite on first run, then starts cds watch on http://localhost:4004
```

---

## Mocked Auth Users (local dev only)

| Username | Password | Role | Permissions |
|---|---|---|---|
| `viewer@test.com` | *(anything)* | `BP_VIEWER` | Read only |
| `processor@test.com` | *(anything)* | `BP_PROCESSOR` | Create / Update / Block |
| `admin@test.com` | *(anything)* | `BP_ADMIN` | Full access incl. Unblock |

When the browser shows a Basic Auth popup, enter any of the above usernames with any password.

---

## Key Service Endpoints

| URL | Description |
|---|---|
| `http://localhost:4004` | CAP welcome page |
| `http://localhost:4004/api/v1/bp` | OData service root |
| `http://localhost:4004/api/v1/bp/$metadata` | OData metadata |
| `http://localhost:4004/api/v1/bp/BusinessPartners` | Business Partners list |
| `http://localhost:4004/api/v1/bp/getBPSummary()` | Aggregate summary function |
| `http://localhost:4004/health` | Health check (CF) |
| `http://localhost:4004/mcp` | MCP server endpoint (AI agent access) |
| `http://localhost:4004/mcp/health` | MCP health check |

### Quick curl tests

```bash
# List all Business Partners
curl -u "admin@test.com:x" http://localhost:4004/api/v1/bp/BusinessPartners

# Summary counts
curl -u "admin@test.com:x" "http://localhost:4004/api/v1/bp/getBPSummary()"

# Block a BP — draft-enabled entities need the compound key incl. IsActiveEntity
curl -u "processor@test.com:x" -X POST \
  "http://localhost:4004/api/v1/bp/BusinessPartners(ID={ID},IsActiveEntity=true)/BPService.blockBP" \
  -H "Content-Type: application/json" -d "{}"

# Unblock a BP (admin only)
curl -u "admin@test.com:x" -X POST \
  "http://localhost:4004/api/v1/bp/BusinessPartners(ID={ID},IsActiveEntity=true)/BPService.unblockBP" \
  -H "Content-Type: application/json" -d "{}"
```

`blockBP`/`unblockBP` are bound actions on `BusinessPartners` (declared inside the entity's `actions { }` block in `bp-service.cds`, not at service level) — referenced in `UI.Identification` by qualified name `BPService.blockBP`, not an `EntityContainer/...` ActionImport path. They also work when invoked against an open draft (`IsActiveEntity=false`), e.g. from the Object Page in edit mode: the handler always updates the persisted active row and mirrors the change into the draft, so Status/Blocked reflect immediately on screen and a later Save doesn't revert it.

---

## CF Deployment

```bash
npm run build      # cds build --production
npm run deploy     # mbt build + cf deploy
```

Requires:
- `cf` CLI logged in to your BTP subaccount
- `mbt` (MTA Build Tool) installed globally: `npm i -g mbt`
- Services pre-created or defined in `mta.yaml`: HANA HDI, XSUAA, Destination, App Logs, HTML5 Repo Runtime
