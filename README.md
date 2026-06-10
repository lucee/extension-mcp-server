# Lucee MCP Server Extension

A [Model Context Protocol (MCP)](https://modelcontextprotocol.io) server packaged as a Lucee extension. Once installed, it exposes Lucee documentation and CFML analysis as MCP tools that AI models (Claude, etc.) can call directly — function and tag descriptors, Lucene full-text search over the docs, and CFML AST parsing and querying (Lucee 7).

## How It Works

The extension deploys an MCP endpoint into the Lucee server context. By default it is reachable at:

```
POST /lucee/mcp/
```

You can also map the extension context to a shorter URL via CFConfig (see [Custom URL mapping](#custom-url-mapping) below) — for example the webroot (`POST /`) or `POST /mcp/`.

AI providers call the endpoint using the JSON-RPC 2.0 protocol. The server handles `initialize` (handshake), `tools/list` (tool discovery) and `tools/call` (tool execution). It is written entirely in CFML — no Java, no Maven dependencies, no external libraries of any kind.

Beyond its use as a Lucee documentation tool, this extension is designed to serve as a starting point for building your own MCP server in CFML. The core protocol handling (`MCPSupport.cfc`) is cleanly separated from the tool implementations (`MCPServer.cfc`), so you can add your own tools — database queries, API integrations, business logic — by following the same pattern.

## Tools

| Tool | Description |
|---|---|
| `get_lucee_function` | Full descriptor for a named Lucee built-in function — arguments, types, defaults, and docs URL |
| `get_lucee_tag` | Full descriptor for a named Lucee tag — attributes, types, defaults, and docs URL |
| `search_lucee_docs` | Full-text search across functions, tags, and recipes. **Requires the Lucene 3 extension**; returns a graceful message if Lucene is not installed |
| `parse_cfml_ast` | Parse CFML source or a file path into an AST JSON tree or compact summary. **Requires Lucee 7.0.0.296+** (`astFromString` / `astFromPath`) |
| `query_cfml_ast` | Find AST nodes by type, name, line, or built-in status in parsed CFML. **Requires Lucee 7.0.0.296+** |

### AST tools

`parse_cfml_ast` and `query_cfml_ast` use Lucee 7's built-in AST functions. Pass either `source` (inline CFML) or `path` (`.cfm` / `.cfc` / `.cfml` file). Optional `mode` is `tag` (default) or `script`.

- `parse_cfml_ast` — full tree JSON, or set `summary: true` for a compact overview; optional `maxDepth` limits nesting
- `query_cfml_ast` — filter with `nodeType` (e.g. `CallExpression`, `CFMLTag`), `name`, `line`, or `builtInOnly: true`

Typical workflow: parse with `parse_cfml_ast` (often with `summary: true`), then drill down with `query_cfml_ast`.

### Documentation search

`search_lucee_docs` indexes Lucee documentation via the Lucene 3 extension (`EFDEB172-F52E-4D84-9CD1A1F561B3DFC8`). Install Lucene on the same Lucee instance, or the tool still appears in `tools/list` but responds with *"Search is not available: Lucene 3 extension is not installed."*

### Adding Your Own Tools

Tools are loaded dynamically from the `tools/` folder. There are two places to add a tool depending on your use case:

**On a running Lucee instance** — drop the component here, no build step needed:
```
<instance>/lucee-server/context/components/org/lucee/extension/mcp/tools/
```

**When extending the extension itself** — add it to the source and rebuild with `mvn package`:
```
source/components/org/lucee/extension/mcp/tools/
```

In both cases Lucee picks it up on next restart (tools are cached at startup).

```javascript
component extends="Tool" {

    variables.name        = "my_tool";
    variables.description = "What this tool does — shown to the AI model.";
    variables.inputSchema = {
        "type"      : "object",
        "properties": {
            "query": { "type": "string", "description": "The input" }
        },
        "required": [ "query" ]
    };

    public function exec( required struct args ) {
        // your logic here
        return toTextContent( "result text" );
    }
}
```

`toTextContent()` is a helper defined on the base `Tool` component that wraps a string into the MCP content array format the protocol expects.

## Installation

Install via the Lucee Administrator or by dropping the `.lex` file into the deploy directory:

```
{lucee-server}/context/deploy/mcp-server-extension-{version}.lex
```

After installation the endpoint is immediately available at `/lucee/mcp/`.

### Custom URL mapping

The extension installs its entry point at `{lucee-config}/context/mcp/` (`index.cfm`). The default public URL is `/lucee/mcp/`, but you can add a server mapping in `.CFConfig.json` so MCP clients use a path that fits your app — for example the webroot or `/mcp`:

**Webroot** — MCP at `POST /` (used in the [Lucee Docker MCP example](https://github.com/lucee/lucee-docs/tree/lucee/examples/docker/mcp)):

```json
"mappings": {
    "/": {
        "physical": "{lucee-config}/context/mcp/"
    }
}
```

**Dedicated path** — MCP at `POST /mcp/`:

```json
"mappings": {
    "/mcp": {
        "physical": "{lucee-config}/context/mcp/"
    }
}
```

Point your MCP client at the mapped URL (e.g. `https://your-host/` or `https://your-host/mcp/`). `/lucee/mcp/` remains available unless you replace the webroot mapping.

## Connecting to Claude

Add the following to your AI engine configuration in `.CFConfig.json`:

```json
"ai": {
  "myclaude": {
    "class": "lucee.runtime.ai.anthropic.ClaudeEngine",
    "custom": {
      "apikey": "${CLAUDE_API_KEY}",
      "model": "claude-sonnet-4-6",
      "headers": {
        "anthropic-beta": "mcp-client-2025-11-20"
      },
      "mcp_servers": [
        {
          "type": "url",
          "url": "https://your-lucee-host.com/lucee/mcp/",
          "name": "lucee-docs"
        }
      ],
      "tools": [
        {
          "type": "mcp_toolset",
          "mcp_server_name": "lucee-docs"
        }
      ]
    }
  }
}
```

Claude will automatically discover and use the tools when answering Lucee-related questions. Usage in CFML is unchanged:

```javascript
aiSession = createAISession( name: "myclaude" );
answer = inquiryAISession( aiSession, "What arguments does arraySort take?" );
writeOutput( answer );
```

## MCP Protocol Reference

All requests are `POST /lucee/mcp/` with `Content-Type: application/json`.

### initialize

Handshake sent by MCP clients on first connect.

**Request:**
```json
{ "jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {} }
```

**Response:**
```json
{
  "jsonrpc": "2.0", "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "serverInfo": { "name": "lucee-docs", "version": "7.x.x.x" },
    "capabilities": { "tools": {} }
  }
}
```

### tools/list

**Request:**
```json
{ "jsonrpc": "2.0", "id": 2, "method": "tools/list" }
```

**Response:** (five tools — names only shown here; each includes `description` and `inputSchema`)

```json
{
  "jsonrpc": "2.0", "id": 2,
  "result": {
    "tools": [
      { "name": "get_lucee_function", "description": "...", "inputSchema": { ... } },
      { "name": "get_lucee_tag", "description": "...", "inputSchema": { ... } },
      { "name": "search_lucee_docs", "description": "...", "inputSchema": { ... } },
      { "name": "parse_cfml_ast", "description": "...", "inputSchema": { ... } },
      { "name": "query_cfml_ast", "description": "...", "inputSchema": { ... } }
    ]
  }
}
```

### tools/call — get_lucee_function

Lookup is case-insensitive. `arraySort`, `ARRAYSORT` and `arraysort` all work.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 3, "method": "tools/call",
  "params": { "name": "get_lucee_function", "arguments": { "name": "arraySort" } }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0", "id": 3,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "## Function arraySort\n\nDocumentation: https://docs.lucee.org/reference/functions/arraysort.html\n\n```json\n{ ... }\n```"
      }
    ]
  }
}
```

If the function is not found, the response still uses `result` (not `error`) with a human-readable not-found message in `content[0].text`.

### tools/call — get_lucee_tag

The `cf` prefix is stripped automatically — `cfquery` and `query` both resolve to the same tag.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 4, "method": "tools/call",
  "params": { "name": "get_lucee_tag", "arguments": { "name": "query" } }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0", "id": 4,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "## Tag cfquery\n\nDocumentation: https://docs.lucee.org/reference/tags/query.html\n\n```json\n{ ... }\n```"
      }
    ]
  }
}
```

### tools/call — parse_cfml_ast

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 5, "method": "tools/call",
  "params": {
    "name": "parse_cfml_ast",
    "arguments": { "source": "<cfset x = arraySort(myArr)>", "summary": true }
  }
}
```

**Response:** JSON text in `content[0].text` — a compact AST summary or full tree depending on `summary` / `maxDepth`.

### tools/call — query_cfml_ast

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 6, "method": "tools/call",
  "params": {
    "name": "query_cfml_ast",
    "arguments": {
      "source": "<cfset x = arraySort(myArr)>",
      "nodeType": "CallExpression",
      "name": "arraySort"
    }
  }
}
```

**Response:** JSON array of matching AST nodes in `content[0].text`.

## Error Codes

The server uses standard JSON-RPC 2.0 error codes:

| Code | Meaning | When |
|---|---|---|
| `-32700` | Parse error | Empty or malformed JSON body |
| `-32600` | Invalid Request | Non-POST request, or missing `method` field |
| `-32601` | Method not found | Unknown JSON-RPC method |
| `-32602` | Invalid params | Missing `name` in `tools/call`, or unknown tool name |
| `-32603` | Internal error | Tool threw an unexpected exception |

## Source Layout

```
source/
  components/org/lucee/extension/mcp/
    MCPServer.cfc      ← JSON-RPC dispatch, loads tools dynamically
    MCPSupport.cfc     ← request reading, response writing, error formatting
    AstSupport.cfc     ← shared AST parse, summarize, and query helpers
    tools/
      Tool.cfc           ← abstract base class for all tools
      Functions.cfc      ← get_lucee_function
      Tags.cfc           ← get_lucee_tag
      SearchLuceeDocs.cfc  ← search_lucee_docs (Lucene)
      ParseCfmlAst.cfc   ← parse_cfml_ast
      QueryCfmlAst.cfc   ← query_cfml_ast
      (add your own here)
  context/
    mcp/
      index.cfm        ← entry point (default URL: /lucee/mcp/)
      Application.cfc  ← sets component paths
  images/
    logo.png
README.md
pom.xml
```

## Building

```bash
mvn package
```

Produces `target/mcp-server-extension-{version}.lex`.

## License

Licensed under the GNU Lesser General Public License v2.1.
See [LICENSE](http://www.gnu.org/licenses/lgpl-2.1.txt) for details.