# Templates — add-excel (executeAsync path)

Substitute `{{dsName}}` (lowercase data source name), `{{tableId}}` (Excel table name),
`{{Name}}` (PascalCase file base name), `{{connectionId}}` (Excel connection GUID).
These are verbatim copies of a verified working implementation — only the names are templatized.

---

## 1. `.power/schemas/appschemas/dataSourcesInfo.ts` entry

Merge this entry into the existing `export const dataSourcesInfo = { ... }` object
(do not remove other data sources):

```ts
"{{dsName}}": {
  "tableId": "{{tableId}}",
  "version": "",
  "primaryKey": "__rowid",
  "dataSourceType": "Connector",
  "apis": {
    "GetItems": {
      "path": "/{connectionId}/drives/{drive}/files/{file}/tables/{tableName}/items",
      "method": "GET",
      "parameters": [
        { "name": "connectionId", "in": "path", "required": true, "type": "string" },
        { "name": "drive", "in": "path", "required": true, "type": "string" },
        { "name": "file", "in": "path", "required": true, "type": "string" },
        { "name": "tableName", "in": "path", "required": true, "type": "string" },
        { "name": "source", "in": "query", "required": true, "type": "string" },
        { "name": "$top", "in": "query", "required": false, "type": "integer" },
        { "name": "$filter", "in": "query", "required": false, "type": "string" },
        { "name": "$orderby", "in": "query", "required": false, "type": "string" }
      ],
      "responseInfo": { "200": { "type": "object" } }
    },
    "AddRowV2": {
      "path": "/{connectionId}/codeless/v1.2/drives/{drive}/items/{file}/workbook/tables/{tableName}/rows",
      "method": "POST",
      "parameters": [
        { "name": "connectionId", "in": "path", "required": true, "type": "string" },
        { "name": "drive", "in": "path", "required": true, "type": "string" },
        { "name": "file", "in": "path", "required": true, "type": "string" },
        { "name": "tableName", "in": "path", "required": true, "type": "string" },
        { "name": "source", "in": "query", "required": true, "type": "string" },
        { "name": "dateTimeFormat", "in": "query", "required": false, "type": "string" },
        { "name": "item", "in": "body", "required": true, "type": "object" }
      ],
      "responseInfo": { "200": { "type": "object" } }
    },
    "PatchItem": {
      "path": "/{connectionId}/drives/{drive}/files/{file}/tables/{tableName}/items/{id}",
      "method": "PATCH",
      "parameters": [
        { "name": "connectionId", "in": "path", "required": true, "type": "string" },
        { "name": "drive", "in": "path", "required": true, "type": "string" },
        { "name": "file", "in": "path", "required": true, "type": "string" },
        { "name": "tableName", "in": "path", "required": true, "type": "string" },
        { "name": "id", "in": "path", "required": true, "type": "string" },
        { "name": "source", "in": "query", "required": true, "type": "string" },
        { "name": "idColumn", "in": "query", "required": true, "type": "string" },
        { "name": "dateTimeFormat", "in": "query", "required": false, "type": "string" },
        { "name": "item", "in": "body", "required": true, "type": "object" }
      ],
      "responseInfo": { "200": { "type": "object" } }
    },
    "DeleteItem": {
      "path": "/{connectionId}/drives/{drive}/files/{file}/tables/{tableName}/items/{id}",
      "method": "DELETE",
      "parameters": [
        { "name": "connectionId", "in": "path", "required": true, "type": "string" },
        { "name": "drive", "in": "path", "required": true, "type": "string" },
        { "name": "file", "in": "path", "required": true, "type": "string" },
        { "name": "tableName", "in": "path", "required": true, "type": "string" },
        { "name": "id", "in": "path", "required": true, "type": "string" },
        { "name": "source", "in": "query", "required": true, "type": "string" },
        { "name": "idColumn", "in": "query", "required": true, "type": "string" }
      ],
      "responseInfo": { "200": { "type": "object" } }
    }
  }
}
```

Note: `{connectionId}` / `{drive}` / `{file}` / `{tableName}` / `{id}` inside `path`
are **runtime placeholders** the SDK fills in — leave them exactly as written.
`{connectionId}` and `{tableName}` are injected automatically by the executor
(from the connection reference and `tableId`); the service only passes the rest.

---

## 2. `src/generated/models/{{Name}}Model.ts`

```ts
/*!
 * Experimental hand-authored model for the Excel Online (Business) table `{{tableId}}`.
 * Excel Online is not natively supported by `pa app add data-source`, so this data source is
 * wired manually against the SDK's generic `executeAsync` connector path.
 * Columns are dynamic; each row is a flat key/value map plus the connector's row id.
 */

export interface {{Name}}Row {
  // The Excel connector returns a synthetic row id for each row.
  __rowid?: string;
  // All table columns come back as string-keyed values.
  [column: string]: string | number | boolean | null | undefined;
}

export interface GetItemsResponse {
  value: {{Name}}Row[];
}

/**
 * The AddRowV2 operation returns the created row as a dynamic object
 * (same flat key/value shape as a table row, including the synthetic row id).
 */
export type AddRowResponse = {{Name}}Row;

/**
 * The PatchItem operation returns the updated row as a dynamic object
 * (same flat key/value shape as a table row, including the synthetic row id).
 */
export type UpdateRowResponse = {{Name}}Row;

/**
 * The DeleteItem operation returns no documented body (expect 200/204 with an
 * empty response). Callers should check `result.success` rather than the data.
 */
export type DeleteRowResponse = Record<string, never>;
```

---

## 3. `src/generated/services/{{Name}}Service.ts`

```ts
/*!
 * Experimental hand-authored service for the Excel Online (Business) table `{{tableId}}`.
 *
 * Excel Online (Business) is NOT supported by `pa app add data-source` (the CRUD path in the SDK
 * is hardcoded to the SharePoint/SQL `datasets/{ds}/tables/{t}/items` shape). This service instead
 * uses the SDK's generic `executeAsync` connector-operation path, which builds the request URL
 * entirely from the `dataSourcesInfo.apis[].path` template declared in
 * `.power/schemas/appschemas/dataSourcesInfo.ts`.
 *
 * The connection is wired via a connection reference in `power.config.json` whose `dataSources`
 * list includes this data source name (`{{dsName}}`).
 */

import type { IOperationResult } from '@microsoft/power-apps/data';
import type {
  {{Name}}Row,
  GetItemsResponse,
  AddRowResponse,
  UpdateRowResponse,
  DeleteRowResponse,
} from '../models/{{Name}}Model';
import { dataSourcesInfo } from '../../../.power/schemas/appschemas/dataSourcesInfo';
import { getClient } from '@microsoft/power-apps/data';

export interface GetRowsParams {
  // Location: "me" | SharePoint site URL | "sites/..." | "groups/..." (see connector docs).
  source: string;
  // Document library: the opaque Graph drive id (b!...). The library NAME 400s.
  drive: string;
  // File: drive-relative path (e.g. "Workbook.xlsx") or the file's driveItem id.
  file: string;
  // Optional OData controls.
  top?: number;
  filter?: string;
  orderby?: string;
}

export interface AddRowParams {
  source: string;
  drive: string;
  file: string;
  // The row to insert: column-name → value map (must match the table's columns).
  row: {{Name}}Row;
  // Optional DateTime serialization format (see connector docs).
  dateTimeFormat?: string;
}

export interface UpdateRowParams {
  source: string;
  drive: string;
  file: string;
  // Key Column: name of the column used to locate the row. CASE-SENSITIVE per connector docs.
  idColumn: string;
  // Key Value: value in the key column identifying the row to update (always a string).
  id: string;
  // Item properties to overwrite; columns left blank/omitted are not updated.
  row: {{Name}}Row;
  dateTimeFormat?: string;
}

export interface DeleteRowParams {
  source: string;
  drive: string;
  file: string;
  // Key Column: name of the column used to locate the row. CASE-SENSITIVE per connector docs.
  idColumn: string;
  // Key Value: value in the key column identifying the row to delete (always a string).
  id: string;
}

export class {{Name}}Service {
  private static readonly dataSourceName = '{{dsName}}';

  private static readonly client = getClient(dataSourcesInfo);

  /**
   * List rows present in the Excel table via the connector's GetItems operation.
   */
  public static async getRows(params: GetRowsParams): Promise<IOperationResult<GetItemsResponse>> {
    const parameters: Record<string, string | number> = {
      source: params.source,
      drive: params.drive,
      file: params.file,
    };
    if (params.top !== undefined) {
      parameters['$top'] = params.top;
    }
    if (params.filter !== undefined) {
      parameters['$filter'] = params.filter;
    }
    if (params.orderby !== undefined) {
      parameters['$orderby'] = params.orderby;
    }

    const result = await {{Name}}Service.client.executeAsync<
      Record<string, string | number>,
      GetItemsResponse
    >({
      connectorOperation: {
        tableName: {{Name}}Service.dataSourceName,
        operationName: 'GetItems',
        parameters,
      },
    });
    return result;
  }

  /**
   * Add a row into the Excel table via the connector's AddRowV2 operation.
   * The `row` object is sent as the raw HTTP body (the executor JSON.stringifies the
   * value of the declared `in: "body"` parameter `item` without wrapping).
   */
  public static async addRow(params: AddRowParams): Promise<IOperationResult<AddRowResponse>> {
    const parameters: Record<string, string | {{Name}}Row> = {
      source: params.source,
      drive: params.drive,
      file: params.file,
      item: params.row,
    };
    if (params.dateTimeFormat !== undefined) {
      parameters['dateTimeFormat'] = params.dateTimeFormat;
    }

    const result = await {{Name}}Service.client.executeAsync<
      Record<string, string | {{Name}}Row>,
      AddRowResponse
    >({
      connectorOperation: {
        tableName: {{Name}}Service.dataSourceName,
        operationName: 'AddRowV2',
        parameters,
      },
    });
    return result;
  }

  /**
   * Update a row in the Excel table via the connector's PatchItem operation.
   * The row is located by `idColumn` (key column, case-sensitive) + `id` (key value);
   * if multiple rows match, only the FIRST is updated (connector limitation).
   * Blank/omitted columns are left unchanged. The executor URL-encodes path params,
   * so `id` must be passed raw (do not pre-encode).
   */
  public static async updateRow(params: UpdateRowParams): Promise<IOperationResult<UpdateRowResponse>> {
    const parameters: Record<string, string | {{Name}}Row> = {
      source: params.source,
      drive: params.drive,
      file: params.file,
      idColumn: params.idColumn,
      id: params.id,
      item: params.row,
    };
    if (params.dateTimeFormat !== undefined) {
      parameters['dateTimeFormat'] = params.dateTimeFormat;
    }

    const result = await {{Name}}Service.client.executeAsync<
      Record<string, string | {{Name}}Row>,
      UpdateRowResponse
    >({
      connectorOperation: {
        tableName: {{Name}}Service.dataSourceName,
        operationName: 'PatchItem',
        parameters,
      },
    });
    return result;
  }

  /**
   * Delete a row from the Excel table via the connector's DeleteItem operation.
   * The row is located by `idColumn` (key column, case-sensitive) + `id` (key value);
   * if multiple rows match, only the FIRST is deleted (connector limitation) — use a
   * unique key column. The connector returns an empty body; check `result.success`
   * rather than `result.data`. The executor URL-encodes path params, so `id` must
   * be passed raw (do not pre-encode).
   */
  public static async deleteRow(params: DeleteRowParams): Promise<IOperationResult<DeleteRowResponse>> {
    const parameters: Record<string, string> = {
      source: params.source,
      drive: params.drive,
      file: params.file,
      idColumn: params.idColumn,
      id: params.id,
    };

    const result = await {{Name}}Service.client.executeAsync<
      Record<string, string>,
      DeleteRowResponse
    >({
      connectorOperation: {
        tableName: {{Name}}Service.dataSourceName,
        operationName: 'DeleteItem',
        parameters,
      },
    });
    return result;
  }
}

export type { {{Name}}Row };
```

---

## 4. `power.config.json` — connection reference

Add under `connectionReferences` (keep existing entries):

```json
"{{connectionId}}": {
  "id": "/providers/Microsoft.PowerApps/apis/shared_excelonlinebusiness",
  "displayName": "Excel Online (Business)",
  "dataSources": ["{{dsName}}"]
}
```

---

## 5. `src/generated/index.ts` — exports

Append:

```ts
export * as {{Name}}Model from './models/{{Name}}Model';
export * from './services/{{Name}}Service';
```

---

## 6. `.env.example`

```bash
# Template for local Excel Online (Business) connector configuration.
# Copy to .env.local and fill in your values. .env.local is gitignored.

# Location of the workbook: "me" | SharePoint site URL | "sites/..." | "groups/..."
VITE_EXCEL_SOURCE=

# Document library: the opaque Graph drive id (b!...) — the library NAME will 400
VITE_EXCEL_DRIVE=

# File: drive-relative path (e.g. "Workbook.xlsx") or the driveItem id
VITE_EXCEL_FILE=

# Optional: table name shown in the UI header
VITE_EXCEL_TABLE_LABEL=
```

## 7. `src/vite-env.d.ts`

```ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Excel connector `source`: "me" | SharePoint site URL | "sites/..." | "groups/..." */
  readonly VITE_EXCEL_SOURCE: string;
  /** Document library: the opaque Graph drive id (b!...) */
  readonly VITE_EXCEL_DRIVE: string;
  /** File: drive-relative path (e.g. "Workbook.xlsx") or the driveItem id */
  readonly VITE_EXCEL_FILE: string;
  /** Display name of the Excel table (used only for UI labels) */
  readonly VITE_EXCEL_TABLE_LABEL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

## 8. `.gitignore` additions

```
.env*
!.env.example
```
