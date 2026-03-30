# Lucee MCP Server Extension

A [Model Context Protocol (MCP)](https://modelcontextprotocol.io) server packaged as a Lucee extension. Once installed, it exposes Lucee's built-in functions and tags as tools that AI models (Claude, etc.) can query directly for accurate, up-to-date documentation.

## How It Works

The extension deploys an MCP endpoint into the Lucee server context, reachable at:

```
POST /lucee/mcp/
```

AI providers call this endpoint using the JSON-RPC 2.0 protocol. The server handles `initialize` (handshake), `tools/list` (tool discovery) and `tools/call` (tool execution). It is written entirely in CFML — no Java, no Maven dependencies, no external libraries of any kind.

Beyond its use as a Lucee documentation tool, this extension is designed to serve as a starting point for building your own MCP server in CFML. The core protocol handling (`MCPSupport.cfc`) is cleanly separated from the tool implementations (`MCPServer.cfc`), so you can add your own tools — database queries, API integrations, business logic — by following the same pattern.

## Tools

| Tool | Description |
|---|---|
| `get_lucee_function` | Returns the full descriptor for a named Lucee built-in function — arguments, types, defaults, and docs URL |
| `get_lucee_tag` | Returns the full descriptor for a named Lucee tag — attributes, types, defaults, and docs URL |

## Installation

Install via the Lucee Administrator or by dropping the `.lex` file into the deploy directory:

```
{lucee-server}/context/deploy/mcp-server-extension-{version}.lex
```

After installation the endpoint is immediately available at `/lucee/mcp/`.

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

**Response:**
```json
{
  "jsonrpc": "2.0", "id": 2,
  "result": {
    "tools": [
      {
        "name": "get_lucee_function",
        "description": "Get the complete descriptor for a specific Lucee built-in function.",
        "inputSchema": {
          "type": "object",
          "properties": { "name": { "type": "string" } },
          "required": [ "name" ]
        }
      },
      {
        "name": "get_lucee_tag",
        "description": "Get the complete descriptor for a specific Lucee tag.",
        "inputSchema": {
          "type": "object",
          "properties": { "name": { "type": "string" } },
          "required": [ "name" ]
        }
      }
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
    MCPServer.cfc      ← JSON-RPC dispatch + tool implementations
    MCPSupport.cfc     ← request reading, response writing, error formatting
  context/
    lucee/mcp/
      index.cfm        ← entry point, accessible at /lucee/mcp/
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