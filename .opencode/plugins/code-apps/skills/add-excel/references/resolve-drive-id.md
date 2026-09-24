# Resolving the Excel drive ID via Graph Explorer

The Excel Online (Business) connector's `drive` parameter must be the **opaque Microsoft
Graph drive id** (starts with `b!`). Passing the document library *name* fails at runtime with:

```
400 – Graph-API request error, code 'invalidRequest':
'The provided drive id appears to be malformed, or does not represent a valid drive.'
```

The agent cannot call Graph itself — the **user** runs the queries in Graph Explorer and
pastes back the JSON. **Always construct the exact URLs for the user** from the values
parsed out of their file link; never make them assemble a URL.

---

## Step-by-step instructions to give the user

Present these steps verbatim (with the concrete URLs filled in):

1. Open **https://developer.microsoft.com/graph/graph-explorer** in your browser.
2. Click **Sign in** (top right) and use your **work account** (same account that owns the Excel connection).
3. Make sure the method dropdown says **GET** and the version says **v1.0**.
4. Paste this URL into the query field:
   `<constructed query — see below>`
5. Click **Run query**.
6. If you get a `403 Forbidden`: open the **Modify permissions** tab under the query field, find **Sites.Read.All** (or **Files.Read.All** for OneDrive), click **Consent**, then run the query again.
7. Copy the whole JSON from the **Response preview** panel and paste it back here.

---

## Query 1 — drive ID

### SharePoint site (`/teams/<site>` or `/sites/<site>`)

From the parsed link `https://<tenant>.sharepoint.com/teams/<site>/<library>/<file>`:

```
https://graph.microsoft.com/v1.0/sites/<tenant>.sharepoint.com:/teams/<site>:/drives?$select=id,name,webUrl
```

(Use `:/sites/<site>:` if the link contains `/sites/`.)

**Interpreting the response:** the `value` array lists the site's document libraries.
Match `name` against the library segment from the file link (note: the URL segment and
display name can differ by language/localization — e.g. URL `Freigegebene Dokumente` /
name `Dokumente`, or URL `Shared Documents` / name `Documents`; match by `webUrl` if
the names don't line up). The matching entry's `id` (`b!…`) is the drive ID.

### OneDrive for Business (own files)

```
https://graph.microsoft.com/v1.0/me/drives?$select=id,name,webUrl
```

Usually a single entry named `OneDrive` — its `id` is the drive ID. For OneDrive,
`source` is `me`.

---

## Optional fallback query — tables in the workbook

The table name normally comes from the user upfront — do NOT run this query in the
standard flow. Use it only when the user does not know the table name or the build/runtime
fails with a table-not-found error. Once the drive ID is known, construct (URL-encode
spaces in the file path as `%20`):

```
https://graph.microsoft.com/v1.0/drives/<driveId>/root:/<file-path>:/workbook/tables?$select=name
```

Example for `Reports/Sales Q3.xlsx`:

```
https://graph.microsoft.com/v1.0/drives/b!AbCd.../root:/Reports/Sales%20Q3.xlsx:/workbook/tables?$select=name
```

**Interpreting the response:**

- The `value` array lists all tables in the workbook — match against what the user said,
  or ask which one to use.
- **Empty** `value` → the worksheet data is not formatted as a table. Tell the user:
  open the workbook → select the data range → **Insert → Table** (check "My table has
  headers") → optionally rename it under **Table Design → Table Name** → save, then
  re-run the query.

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `403 Forbidden` on Query 1 | Consent to **Sites.Read.All** in the Modify permissions tab |
| `404 itemNotFound` on Query 2 | The file path is wrong relative to the drive root — it must NOT include the library name (the drive IS the library). Check casing and spaces (`%20`). |
| `400 invalidRequest ... site` on Query 1 | The site path is wrong — verify `/teams/` vs `/sites/` and the site segment from the original link |
| Drive names don't match the URL segment | Match by `webUrl` instead of `name` (localized library names) |
| User can't access Graph Explorer (blocked by policy) | Ask a colleague/admin to run the two GET queries, or resolve `me/drives` via any Graph-capable tool; only the two read-only queries above are needed |
