---
name: add-excel
description: Adds Excel Online (Business) connector to a Power Apps code app. User provides the Excel file link and the table name upfront; the only other interaction is a guided step-by-step Graph Explorer walkthrough to get the drive ID. Generates the model + service (SDK executeAsync path), wires config, and builds. Use when reading or writing Excel workbook data from OneDrive or SharePoint.
user-invocable: true
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, LSP, TaskCreate, TaskUpdate, TaskList, TaskGet, AskUserQuestion, Skill
model: sonnet
---

**📋 Shared Instructions: [shared-instructions.md](.opencode/plugins/code-apps/shared/shared-instructions.md)** - Cross-cutting concerns.

# Add Excel Online (Business)

## Background (why not the CLI)

`pa app add data-source --connector shared_excelonlinebusiness` fails with **HTTP 400**: Excel Online is on Microsoft's ["Connectors that aren't yet supported"](https://learn.microsoft.com/power-apps/developer/code-apps/how-to/connect-to-data) list for code apps, and the CLI's tabular model (`--dataset` + `--table`) cannot express Excel's three selectors (`source`, `drive`, `file`).

**But the SDK's generic `executeAsync` path has no connector allowlist** — it builds URLs purely from `dataSourcesInfo.apis[operation].path` templates. Hand-authoring the artifacts the CLI would normally generate makes Excel work end-to-end (verified: full CRUD against a SharePoint-hosted workbook). This skill does exactly that, automatically.

All file templates are in [references/templates.md](references/templates.md). The drive-ID walkthrough is in [references/resolve-drive-id.md](references/resolve-drive-id.md).

## Design principle: ask as little as possible

The user provides **two things upfront: the link to the Excel file and the table name**. The **only** other interaction is the guided Graph Explorer walkthrough for the drive ID — never ask anything else:

| Value | How it is obtained |
| --- | --- |
| File link + `tableId` | Provided by the user upfront (one combined question if not already given) |
| `source` | Parsed from the pasted link (site URL, or `me` for OneDrive) |
| `file` | Parsed from the pasted link (workbook path within the library) |
| `drive` | User runs ONE copy-paste Graph Explorer query that YOU construct for them, with a full step-by-step guide |
| `{{dsName}}` / `{{Name}}` | Derived from the table name (lowercase / PascalCase). Never ask |
| `{{connectionId}}` | Found via `/list-connections` skill |

Never ask the user for anything you can derive or look up. Never ask for confirmation of parsed values — state them and proceed.

## Workflow

1. Check Memory Bank → 2. Get link + table name → 3. Parse the link → 4. Resolve drive ID via Graph (guided, step-by-step) → 5. Connection ID → 6. Generate artifacts → 7. Env config → 8. Build → 9. Update Memory Bank

---

### Step 1: Check Memory Bank

Check for `memory-bank.md` per [shared-instructions.md](.opencode/plugins/code-apps/shared/shared-instructions.md).

If Excel is already wired (data source exists in `.power/schemas/appschemas/dataSourcesInfo.ts` + `power.config.json`), confirm with the user whether they want another table or a change to the existing one.

### Step 2: Get link + table name

If the user already provided the file link and table name in their request, use them and skip ahead. Otherwise ask ONE combined question:

> 1. Paste the link to your Excel file (from SharePoint or OneDrive — 'Copy link' or the browser URL is fine).
> 2. What is the name of the table inside the workbook? (In Excel: click inside the data → **Table Design** tab → **Table Name**, e.g. `tblSales`.)

The table name the user provides is `{{tableId}}`. Do not verify it via Graph — trust the user.

### Step 3: Parse the link

Decode the URL (`%20` → space etc.) and strip query strings / `/:x:/r/` sharing-link segments. Then classify:

**SharePoint** (`https://<tenant>.sharepoint.com/teams/<site>/...` or `/sites/<site>/...`):

- `source` = `https://<tenant>.sharepoint.com/teams/<site>` (site URL up to and including the site segment)
- library = first path segment after the site (e.g. `Shared Documents`, `Freigegebene Dokumente`, or a custom library name)
- `file` = remaining path within the library (e.g. `Reports/Sales.xlsx`)

**OneDrive for Business** (`https://<tenant>-my.sharepoint.com/personal/<user>/...`):

- If the workbook belongs to the signed-in user: `source` = `me`, `drive` = `me` may work; otherwise resolve the drive via `GET /me/drives` in Step 4.
- `file` = path after `Documents/`

State the parsed values (`source`, library, `file`) in your reply and proceed — do NOT ask for confirmation.

### Step 4: Resolve the drive ID via Graph (guided, step-by-step)

The connector's `drive` parameter must be the **opaque Graph drive id (`b!…`)** — the library name 400s at runtime. This is the ONLY thing you may ask the user for beyond Step 2, and it must ALWAYS come with a full numbered step-by-step guide (see [references/resolve-drive-id.md](references/resolve-drive-id.md)).

1. **Construct the exact Graph query yourself** from the parsed link (never make the user build a URL):
   - SharePoint: `https://graph.microsoft.com/v1.0/sites/<tenant>.sharepoint.com:/teams/<site>:/drives?$select=id,name,webUrl` (use `:/sites/<site>:` for `/sites/` links)
   - OneDrive: `https://graph.microsoft.com/v1.0/me/drives?$select=id,name,webUrl`
2. **Present the full walkthrough** — always give ALL of these steps, never just the URL:
   > 1. Open **https://developer.microsoft.com/graph/graph-explorer** in your browser.
   > 2. Click **Sign in** (top right) and use your **work account** (the same account that owns the Excel connection).
   > 3. Make sure the method dropdown says **GET** and the version says **v1.0**.
   > 4. Paste this URL into the query field: `<the constructed URL>`
   > 5. Click **Run query**.
   > 6. If you get **403 Forbidden**: open the **Modify permissions** tab below the query field, consent to **Sites.Read.All** (or **Files.Read.All** for OneDrive), then run the query again.
   > 7. Copy the whole JSON from the **Response preview** panel and paste it back here.
3. From the pasted response, pick the drive whose `name` (or `webUrl`) matches the library from Step 3 → that `id` (`b!…`) is the drive ID. Match it yourself — do NOT ask the user to pick; only ask if nothing matches.

Troubleshooting (403, localized library names, itemNotFound): [references/resolve-drive-id.md](references/resolve-drive-id.md).

### Step 5: Connection ID

Run the `/list-connections` skill and find the Excel Online (Business) (`shared_excelonlinebusiness`) connection. If none exists, direct the user to create one: `https://make.powerapps.com/environments/<environment-id>/connections` (environment ID from `power.config.json`) → **+ New connection** → Excel Online (Business) → Create — then re-run `/list-connections`.

### Step 6: Generate artifacts

Derive names yourself (no questions): `{{dsName}}` = lowercase alphanumeric form of the table name (without a `tbl` prefix), `{{Name}}` = PascalCase of the same.

Create/edit these files using the exact templates in [references/templates.md](references/templates.md), substituting `{{dsName}}`, `{{tableId}}`, `{{Name}}`, `{{connectionId}}`:

a. **`.power/schemas/appschemas/dataSourcesInfo.ts`** — merge in a `{{dsName}}` entry (`tableId`, `primaryKey: "__rowid"`, `dataSourceType: "Connector"`) with `apis`: `GetItems`, `AddRowV2`, `PatchItem`, `DeleteItem`. Leave `{connectionId}`/`{drive}`/`{file}`/`{tableName}`/`{id}` placeholders in the paths exactly as written — the SDK fills them at runtime.
b. **`src/generated/models/{{Name}}Model.ts`** — dynamic row type (`{ __rowid?: string; [column: string]: ... }`) + response types.
c. **`src/generated/services/{{Name}}Service.ts`** — class using `getClient(dataSourcesInfo)` + `executeAsync` with `getRows` / `addRow` / `updateRow` / `deleteRow`.
d. **`power.config.json`** — add under `connectionReferences` (keep existing entries):
   ```json
   "{{connectionId}}": {
     "id": "/providers/Microsoft.PowerApps/apis/shared_excelonlinebusiness",
     "displayName": "Excel Online (Business)",
     "dataSources": ["{{dsName}}"]
   }
   ```
   If the Excel connection reference already exists, just append `{{dsName}}` to its `dataSources` array.
e. **`src/generated/index.ts`** — append exports:
   ```ts
   export * as {{Name}}Model from './models/{{Name}}Model';
   export * from './services/{{Name}}Service';
   ```

Repeat (a)–(c) + the `dataSources` entry for each additional table the user asked for.

### Step 7: Env config

The workbook location must NOT be committed. Wire Vite env variables (templates in [references/templates.md](references/templates.md)):

1. Create/append **`.env.example`** with `VITE_EXCEL_SOURCE`, `VITE_EXCEL_DRIVE`, `VITE_EXCEL_FILE`, `VITE_EXCEL_TABLE_LABEL`.
2. Ensure **`.gitignore`** has:
   ```
   .env*
   !.env.example
   ```
3. Add the typings to **`src/vite-env.d.ts`**.
4. **Write `.env.local` yourself** with the resolved values from Steps 3–4 (source, `b!…` drive id, file path, table name) — the user already gave you everything; don't make them copy values around. Confirm `.env.local` is gitignored before writing.

### Step 8: Build

```bash
npm run build
```

Fix TypeScript errors before proceeding. Do NOT deploy — suggest `pa app run` for a local test, then `/deploy` when the user is satisfied.

### Step 9: Update Memory Bank

Update `memory-bank.md` with: Excel connector wired via executeAsync (data source name, table, connection ID, source/drive/file summary — no secrets), env variables required, build status.

---

## Usage example (for the user's components)

```typescript
import { SalesdataService } from '../generated';

const source = import.meta.env.VITE_EXCEL_SOURCE;
const drive = import.meta.env.VITE_EXCEL_DRIVE;
const file = import.meta.env.VITE_EXCEL_FILE;

// Read
const res = await SalesdataService.getRows({ source, drive, file, top: 100 });
const rows = res.data?.value ?? [];

// Create — flat column→value map, NO "items" wrapper
await SalesdataService.addRow({ source, drive, file, row: { Product: "X", Amount: 5 } });

// Update / Delete — located by key column + key value (first match only; idColumn is case-sensitive)
await SalesdataService.updateRow({ source, drive, file, idColumn: "Id", id: "42", row: { Amount: 6 } });
await SalesdataService.deleteRow({ source, drive, file, idColumn: "Id", id: "42" });
```

## Caveats

- **Unofficial path.** These files mimic CLI-generated output but are hand-authored. A future SDK/runtime change could alter `executeAsync` URL-building or add a connector guard.
- **The `b!…` drive id is environment-specific.** If the file moves or the app is promoted, re-resolve it (Step 4) and update `.env.local` / pipeline env config.
- **Vite inlines `VITE_*` values at build time** — the env-var split keeps tenant details out of git, not out of the deployed JS bundle.
- **Connector limits:** `GetItems` caps at 256 rows by default (use `$top`/pagination); `PatchItem`/`DeleteItem` act on the FIRST match of `idColumn` + `id` only — use a unique key column; `idColumn` is case-sensitive.
- **Do not pre-encode** the `id` path value — the executor URL-encodes path params itself.
- `DeleteItem` returns an empty body — check `result.success`, not `result.data`.
