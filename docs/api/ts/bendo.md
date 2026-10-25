---
module: bendo
---

# bendo

The package's main entry point holds the pieces of `bendo openapi` as
functions, so a build script can generate the [OpenAPI document](../../openapi.md)
itself, and `findBend`, which locates the Bend compiler. The command line is
covered in [Develop with the CLI](../../cli.md).

```sh
bun add -d bendo
```

## Types

### `OpenApiConfig`

```ts signature
type OpenApiConfig = {
  info?: InfoConfig | undefined;
  servers?: Server[] | undefined;
  tags?: Tag[] | undefined;
  autoTags?: boolean | undefined;
  allMethods?: OperationMethod[] | undefined;
  exclude?: string[] | undefined;
  operations?: Record<string, OperationOverride> | undefined;
};
```

The options for `generateOpenApi`, the same members `openapi.config.json`
holds. Every member is optional; the
[configuration table](../../openapi.md#configuration) lists the defaults.
`operations` is keyed by the manifest's `METHOD path`, such as
`GET /todos/:id{int}`.

```ts
import type { OpenApiConfig } from "bendo";

const config: OpenApiConfig = {
  info: { title: "Todo API", version: "1.2.0" },
  servers: [{ url: "https://api.example.com" }],
  exclude: ["/openapi.json", "/docs"],
  operations: { "GET /todos/:id{int}": { summary: "Get a todo", operationId: "getTodo" } },
};
```

### `OpenApiDocument`, `OpenApiResult`

```ts signature
type OpenApiDocument = {
  openapi: "3.1.1";
  info: Info;
  servers?: Server[];
  tags?: Tag[];
  paths: Record<string, PathItem>;
};
type OpenApiResult = { document: OpenApiDocument; warnings: string[] };
```

An OpenAPI 3.1.1 document, and what `generateOpenApi` returns: the document
plus one warning per route or override it could not document. `info.title` and
`info.version` are always set.

```ts
import { generateOpenApi, type OpenApiDocument, type OpenApiResult } from "bendo";

const result: OpenApiResult = generateOpenApi({ bendo: 1, routes: [] });
const document: OpenApiDocument = result.document;
console.log(document.openapi, Object.keys(document.paths).length);
```

### `BendInstall`

```ts signature
type BendInstall = { kind: "found"; path: string; version: string } | { kind: "missing" };
```

The result of `findBend`. `version` is the `x.y.z` that `bend version`
printed, or `"unknown"` when it printed none.

```ts
import type { BendInstall } from "bendo";

function describeBend(install: BendInstall): string {
  switch (install.kind) {
    case "found":
      return `bend ${install.version} at ${install.path}`;
    case "missing":
      return "bend is not installed";
    default: {
      const exhaustive: never = install;
      return exhaustive;
    }
  }
}
```

## Generate OpenAPI

### `generateOpenApi`

```ts signature
function generateOpenApi(manifest: Manifest, options?: OpenApiConfig): OpenApiResult;
```

Builds the document from a [route manifest](../../manifest.md), the JSON a
compiled app prints with `--bendo-routes`. Routes keep manifest order; when two
routes give the same method on the same OpenAPI path, the first wins and the
later one gets a warning. A route pattern the generator cannot parse throws.
[Mapping](../../openapi.md#mapping) describes how patterns, methods and schema
slots become OpenAPI. The `Manifest` type is not exported; read it as
`Parameters<typeof generateOpenApi>[0]`.

Unlike the command, the function does not read `package.json`: without
`info`, the title is `Bendo API` and the version `0.0.0`.

```ts
import { generateOpenApi } from "bendo";

const { document, warnings } = generateOpenApi(
  {
    bendo: 1,
    routes: [
      {
        method: "GET",
        path: "/todos/:id{int}",
        params: ["id"],
        all: false,
        schemas: { response: { type: "object", properties: { title: { type: "string" } } } },
      },
    ],
  },
  { info: { title: "Todo API", version: "1.0.0" } },
);
for (const warning of warnings) console.warn(warning);
console.log(Object.keys(document.paths)); // ["/todos/{id}"]
```

### `parseOpenApiConfig`

```ts signature
function parseOpenApiConfig(value: unknown): OpenApiConfig;
```

Checks a parsed `openapi.config.json` value and returns it typed. It throws an
`Error` naming the member for an unknown member, a wrongly typed value, a
license with both `identifier` and `url`, or an `allMethods` entry that is not
a lowercase OpenAPI method.

```ts
import { parseOpenApiConfig } from "bendo";

const config = parseOpenApiConfig(await Bun.file("openapi.config.json").json());
console.log(config.info?.title ?? "Bendo API");
```

### `documentText`

```ts signature
function documentText(document: OpenApiDocument, indent?: number): string;
```

The document as JSON text, indented by `indent` spaces (default 2), with a
trailing newline. Characters from U+007F up are written as `\uXXXX` escapes, so
the text is ASCII. `bendo openapi` writes `openapi.json` this way.

```ts
import { documentText, generateOpenApi } from "bendo";

const { document } = generateOpenApi({ bendo: 1, routes: [] });
await Bun.write("openapi.json", documentText(document));
```

### `bendModule`

```ts signature
function bendModule(text: string): string;
```

The source of a Bend module whose `json()` returns `text` with trailing
whitespace removed. The text is split into 256-character string literals, one
def each, because Bend overflows on one large literal. This is the file
`bendo openapi --bend` writes; serve it with `Docs.openapi` as in the
[OpenAPI quick start](../../openapi.md#quick-start).

```ts
import { bendModule, documentText, generateOpenApi } from "bendo";

const { document } = generateOpenApi({ bendo: 1, routes: [] });
await Bun.write("openapi-doc.bend", bendModule(documentText(document, 0)));
```

## Locate Bend

### `findBend`

```ts signature
function findBend(): BendInstall;
```

Looks for `bend` on `PATH`, then in `~/.bend/bin`, and runs `bend version`.
The version check waits up to 30 seconds and is tried twice before it gives
`"unknown"`. It uses `Bun.which` and `Bun.spawnSync`, so it runs under Bun
only.

```ts
import { findBend } from "bendo";

const bend = findBend();
if (bend.kind === "missing") throw new Error("Install Bend from https://bend-lang.com");
console.log(`using ${bend.path} (${bend.version})`);
```
