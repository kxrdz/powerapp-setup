# powerapp-setup
## Table of contents

1. [Prerequisites](#prerequisites)
2. [Quick start](#quick-start)
3. [Run locally](#run-locally)
4. [Connect data (connectors & data sources)](#connect-data-connectors--data-sources)
5. [Deploy / push to Power Platform](#deploy--push-to-power-platform)
6. [Project structure](#project-structure)
7. [Scripts](#scripts)
8. [Working with the agent skills](#working-with-the-agent-skills)
9. [Important rules & limitations](#important-rules--limitations)
10. [Troubleshooting](#troubleshooting)
11. [Resources](#resources)

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **Node.js 22+ (LTS)** | `node -v` |
| **Git** | recommended |
| **Power Platform environment** with **code apps enabled** | Admin Center → Environments → *your env* → Settings → Product → Features → **Enable code apps** |
| **Maker permissions** in that environment | you must be able to create apps |
| **Power Apps Premium license** for end users | required for anyone who *runs* the app (or Pay-as-you-go / App Pass) |
| **Environment ID** (GUID) | copy it from the URL at `https://make.powerapps.com/environments/<env-id>/...` |

The Power Apps CLI (`@microsoft/power-apps-cli`) is installed **locally** through `npm install`, so there is nothing to install globally. It is invoked as `npx --no-install pa …` in this README.


---

## Quick start

```bash
npm install

# 0. Check / fix the machine setup (Node, CLI, keyring, sign-in, registration)
npm run doctor

# 1. Sign in to Power Platform
npx --no-install pa auth login
npx --no-install pa auth status

# 2. Register this project as a code app in your environment
#    -> creates power.config.json (environment ID + app ID)
npx --no-install pa app init --display-name "My App" --environment-id <env-id>

# 4. Run locally against real connections
npx --no-install pa app run

# 5. Build and publish
npm run build
npx --no-install pa app push
```

After `pa app push` the CLI prints the app URL (`https://apps.powerapps.com/play/e/<env-id>/a/<app-id>`). Share the app from [make.powerapps.com](https://make.powerapps.com) or via `pa app share`.

---

## Run locally

There are two ways to run the app on your machine:

### `pa app run` (recommended — real Power Platform context)

```bash
npx --no-install pa app run
```

Starts the Vite dev server **and** a local Power Apps host bridge. The app runs on `localhost` but authenticates against your tenant and uses the **real connections** of your environment, so generated data services (Dataverse, SharePoint, …) work exactly as in production. No deploy cycle needed to test data access.

**Browser gotcha:** open the local URL in the **same browser profile** that is signed in to your Power Platform tenant. Chrome/Edge may ask for permission to let a public origin talk to a local endpoint — allow it.

### `npm run dev` (plain Vite, UI only)

```bash
npm run dev
```

Fast UI iteration without Power Platform context. Anything that touches a connector will not work here; use this only for layout/component work.

### Other local commands

```bash
npm run lint       # eslint
npm run build      # tsc -b && vite build  -> dist/
npm run preview    # serve the production build locally
```

---

## Connect data (connectors & data sources)

Code apps run in a sandbox: **`fetch`, `axios`, direct Graph/REST calls do not work at runtime**. All data goes through Power Platform connectors. The CLI generates typed TypeScript services for each data source you add.

### 1. Create or find a connection

Connections (the authenticated instance of a connector) live in the environment, not in the repo.

```bash
# find the connector's API name
npx --no-install pa connector list --search sharepoint

# list existing connections and their IDs
npx --no-install pa connection list

# create a connection if none exists (opens a consent flow)
npx --no-install pa connection create --connector shared_sharepointonline
```

Alternatively create it in the portal: `https://make.powerapps.com/environments/<env-id>/connections` → **+ New connection**.

### 2. Add the data source

**Dataverse** (no connection ID needed — uses your user's Dataverse access):

```bash
npx --no-install pa app add data-source --connector dataverse --table account
```

**Tabular connectors** (SharePoint, SQL, …) need a connection ID, a dataset and a table:

```bash
# discover dataset (site) and tables
npx --no-install pa connector list-datasets --connector sharepointonline -c <connection-id>
npx --no-install pa connector list-tables   --connector sharepointonline -c <connection-id> -d 'https://contoso.sharepoint.com/sites/Team'

# add
npx --no-install pa app add data-source --connector sharepointonline -c <connection-id> \
  -d 'https://contoso.sharepoint.com/sites/Team' --table 'Tasks'
```

**Action connectors** (Office 365 Outlook, Teams, OneDrive, Azure DevOps, Copilot Studio, …) only need a connection ID:

```bash
npx --no-install pa app add data-source --connector shared_office365 -c <connection-id>
npx --no-install pa app add data-source --connector shared_teams     -c <connection-id>
```

**Power Automate flows** (solution-aware flows in the same environment):

```bash
npx --no-install pa app list-flows
npx --no-install pa app add flow
```

Each command updates `power.config.json` and generates:

```
src/generated/
├── models/<Name>Model.ts      # TypeScript interfaces
└── services/<Name>Service.ts  # typed CRUD / action methods
```

Refresh after schema changes, or remove a source:

```bash
npx --no-install pa app refresh data-source --name <name>
npx --no-install pa app remove  data-source --connector <api> --name <name>
```

### 3. Use the generated service in React

```tsx
import { useQuery } from "@tanstack/react-query";
import { AccountsService } from "@/generated/services/AccountsService";

export function AccountsList() {
  const { data, isLoading } = useQuery({
    queryKey: ["accounts"],
    queryFn: async () => {
      const result = await AccountsService.getAll({
        select: ["name", "accountnumber"],
        filter: "statecode eq 0",
        orderBy: ["name asc"],
        top: 50,
      });
      return result.data ?? [];
    },
  });

  if (isLoading) return <p>Loading…</p>;
  return <ul>{data?.map((a) => <li key={a.accountid}>{a.name}</li>)}</ul>;
}
```

Rules of thumb:

- Always use the generated services; never `fetch` external APIs.
- Read `result.data` — the services return a result envelope.
- Do **not** hand-edit `src/generated/` or `power.config.json`; re-run the CLI instead.
- Dataverse gotchas: option sets are integers, lookups are `_field_value`, related records are set with `@odata.bind`.

Supported connector skills in this repo: Dataverse, SharePoint, Office 365 Outlook, Teams, OneDrive, Excel Online (Business), Azure DevOps, Copilot Studio, Work IQ, plus a generic fallback for any other connector (see [agent skills](#working-with-the-agent-skills)).

---

## Deploy / push to Power Platform

```bash
npm run build                       # always build first -> dist/
npx --no-install pa app push        # uploads dist/ + power.config.json
```

- `pa app push` publishes a new version of the app registered in `power.config.json`. Existing sharing and settings are kept.
- First-time users are prompted for connection consent when they open the app.
- Hide the Power Apps header for line-of-business apps:
  `npx --no-install pa app set-setting --show-header false` (or per-URL with `?hideNavBar=true`).
- List code apps in the environment: `npx --no-install pa app list`.

### Deploy to a different environment

`power.config.json` is bound to one environment. To target another one, either run `pa app init` again with a different `--environment-id` (creates a new app) or, preferably, put the app in a **solution** and move it through Power Platform Pipelines (Dev → Test → Prod).

### CI/CD

Non-interactive push with a service principal, inside a solution:

```bash
PA_CLI_SOLUTION_ID=<solution-guid> npx --no-install pa app push
```

Commit `power.config.json` so the pipeline knows which app to update; do **not** commit `dist/` (add it to `.gitignore`).

---

## Project structure

```
powerapp-setup/
├── index.html
├── vite.config.ts            # react() + tailwindcss() + powerApps() plugins, "@" alias -> src/
├── components.json           # shadcn/ui config (new-york style, lucide icons)
├── eslint.config.js
├── tsconfig*.json
├── power.config.json         # created by `pa app init` — env ID, app ID, data sources (do not edit)
├── docs/
│   └── einfuehrung-power-apps-code-apps.md   # German developer intro to code apps
├── .opencode/                # OpenCode agent plugins & skills (code-apps, power-automate, impeccable)
├── opencode.json             # skills + MCP servers (flowagent, microsoft-learn)
└── src/
    ├── main.tsx              # React root
    ├── App.tsx               # ThemeProvider > Sonner > QueryProvider > RouterProvider
    ├── router.tsx            # React Router with Power Apps basename fix (do not remove)
    ├── index.css             # Tailwind v4 + shadcn theme tokens (light/dark)
    ├── pages/                # _layout.tsx, home.tsx, not-found.tsx
    ├── components/ui/        # shadcn/ui components (button, card, table, dialog, …)
    ├── components/mode-toggle.tsx
    ├── providers/            # theme, query, sonner providers
    ├── hooks/                # use-theme
    ├── lib/utils.ts          # cn()
    └── generated/            # created by `pa app add data-source` (models + services)
```

### Pre-installed libraries

- [Tailwind CSS v4](https://tailwindcss.com/) + [tw-animate-css](https://github.com/Wombosvideo/tw-animate-css)
- [shadcn/ui](https://ui.shadcn.com/) (Radix primitives) — add more with `npx shadcn@latest add <component>`
- [React Router v7](https://reactrouter.com/)
- [Zustand](https://zustand.docs.pmnd.rs/) — client state
- [TanStack Query](https://tanstack.com/query/latest) — server state / data fetching
- [TanStack Table](https://tanstack.com/table/latest) — data grids
- [Recharts](https://recharts.org/), [Sonner](https://sonner.emilkowal.ski/), [Lucide](https://lucide.dev/), [date-fns](https://date-fns.org/), [react-day-picker](https://daypicker.dev/)

---

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Vite dev server (UI only, no Power Platform context) |
| `npm run build` | Type-check + production build to `dist/` |
| `npm run preview` | Serve `dist/` locally |
| `npm run lint` | ESLint |
| `npm run doctor` | Check the setup and offer to fix what is missing (`-- --check` = report only, `-- --yes` = fix without asking) |
| `npx --no-install pa auth login` | Sign in to Power Platform |
| `npx --no-install pa app init -n "<name>" -e <env-id>` | Register the app, create `power.config.json` |
| `npx --no-install pa app run` | Local dev with real connections |
| `npx --no-install pa app push` | Deploy `dist/` |
| `npx --no-install pa connection list` | List connections and IDs |
| `npx --no-install pa app add data-source …` | Add connector / table, generate services |
| `npx --no-install pa app add flow` | Add a Power Automate flow |

Full CLI reference: <https://learn.microsoft.com/power-apps/developer/code-apps/reference/cli>

---

## Working with the agent skills

This repo is configured for [OpenCode](https://opencode.ai). Open it in OpenCode and the skills under `.opencode/plugins/` become available. They run the same `pa` commands described above, but interactively:

| Skill | Use it to |
|---|---|
| `create-code-app` | scaffold + init + deploy a new code app |
| `deploy` | build and push the current app |
| `list-connections` | find connection IDs |
| `add-datasource` | pick the right connector skill |
| `add-dataverse`, `add-sharepoint`, `add-office365`, `add-teams`, `add-onedrive`, `add-excel`, `add-azuredevops`, `add-mcscopilot`, `add-workiq`, `add-connector` | add a specific connector and generate services |
| `browse-flows`, `create-flow`, `build-flow`, `debug-flow`, `manage-flows` | work with Power Automate flows via the `flowagent` MCP server |
| `impeccable` | frontend design review / polish |

The `flowagent` MCP server needs the Azure CLI (`az login`) — run the `setup` skill if it fails.

---

## Important rules & limitations

- **Connector-first.** No `fetch`/`axios`/Graph calls at runtime. Everything through generated services.
- **Never hardcode secrets** into the bundle — the compiled assets are on a public endpoint (no SAS IP restriction). Load data through data sources so auth + authorization apply.
- Keep the basename code in `src/router.tsx` — it makes React Router work under `apps.powerapps.com/play/...`.
- `power.config.json` and `src/generated/` are owned by the CLI.
- Not supported today: Power Apps for Windows, Dataverse for Teams environments, offline, Power BI `PowerBIIntegration`, SharePoint Forms, Power Platform Git integration (use your own Git — this repo).
- Excel Online (Business) is not on the standard CLI path; the `add-excel` skill implements the `executeAsync` workaround.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Anything setup-related | Run `npm run doctor` first — it detects and offers fixes for the issues below. |
| `CachePersistenceError: … org.freedesktop.secrets was not provided` (Linux/WSL) | No keyring service. `sudo apt install gnome-keyring`, then `npm run doctor` to unlock it. |
| `pa` commands hang (Linux/WSL) | The keyring is locked. `npm run doctor` asks for the keyring password and unlocks it. |
| `Cannot find module '../build/Release/keytar.node'` | You ran a broken global `pa`. Use `npx --no-install pa …`; `npm run doctor` offers to remove the global copy. |
| `npx: pa not found` | Run `npm install` in the project root; the CLI is a local dev dependency. Always use `npx --no-install pa`, never bare `npx pa`. |
| `pa app init` fails with permission error | Ask the environment admin to enable **code apps** and give you maker rights. |
| `CONNECTION_ID argument is required` | Non-Dataverse connectors need `-c <connection-id>`; get it from `pa connection list`. |
| App loads locally but data calls fail | You used `npm run dev`; use `pa app run` instead, in the browser profile signed in to the tenant. |
| Blank page after deploy / routes 404 | Ensure the basename block in `src/router.tsx` is intact and you ran `npm run build` before `pa app push`. |
| Users get "license required" | End users need Power Apps Premium (or PAYG). |
| TypeScript errors in `src/generated/` after schema change | `pa app refresh data-source --name <name>`. |

---

## Resources

- Code apps overview: <https://learn.microsoft.com/power-apps/developer/code-apps/overview>
- CLI reference: <https://learn.microsoft.com/power-apps/developer/code-apps/reference/cli>
- Samples & templates: <https://github.com/microsoft/PowerAppsCodeApps>
- German intro talk in this repo: [`docs/einfuehrung-power-apps-code-apps.md`](docs/einfuehrung-power-apps-code-apps.md)
