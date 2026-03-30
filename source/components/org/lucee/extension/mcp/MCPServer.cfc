/**
 * Lucee Documentation MCP Server
 *
 * Implements the Model Context Protocol (MCP) over HTTP/JSON-RPC 2.0.
 * Exposes Lucee functions, tags and recipes as searchable tools so that
 * AI models (Claude, etc.) can retrieve accurate, up-to-date documentation
 * without hallucinating API details.
 *
 * Endpoint : POST /mcp/
 * Methods  : tools/list, tools/call
 *
 * Tools:
 *   search_lucee_docs  - full-text search across functions, tags and recipes
 *   get_lucee_function - retrieve full descriptor for a specific function
 *   get_lucee_tag      - retrieve full descriptor for a specific tag
 */
component extends="MCPSupport" {

	// MCP protocol version this server targets
	static.PROTOCOL_VERSION = "2024-11-05";
	static.SERVER_NAME       = "lucee-docs";
	static.SERVER_VERSION    = server.lucee.version;

	// -------------------------------------------------------------------------
	// Tool definitions - returned by tools/list
	// -------------------------------------------------------------------------
	static.tools = [
		{
			"name"        : "get_lucee_function",
			"description" : "Get the complete descriptor for a specific Lucee built-in function. "
			              & "Returns argument names, types, descriptions and examples. "
			              & "Use this when you know the exact function name and need its full signature.",
			"inputSchema" : {
				"type"      : "object",
				"properties": {
					"name": {
						"type"       : "string",
						"description": "The function name, e.g. 'arraySort', 'listToArray', 'dateAdd'"
					}
				},
				"required": [ "name" ]
			}
		},
		{
			"name"        : "get_lucee_tag",
			"description" : "Get the complete descriptor for a specific Lucee tag. "
			              & "Returns attribute names, types, descriptions and examples. "
			              & "Use this when you know the exact tag name and need its full specification.",
			"inputSchema" : {
				"type"      : "object",
				"properties": {
					"name": {
						"type"       : "string",
						"description": "The tag name without prefix, e.g. 'query', 'loop', 'http'"
					}
				},
				"required": [ "name" ]
			}
		}
	];

	// -------------------------------------------------------------------------
	// Init
	// -------------------------------------------------------------------------
	public function init() {
		return this;
	}

	// -------------------------------------------------------------------------
	// Main dispatch - called from index.cfm
	// -------------------------------------------------------------------------
	public function handle() {
		var req = readRequest();

		// JSON-RPC requires id + method
		if ( !structKeyExists( req, "method" ) ) {
			writeError( id: req.id ?: nullValue(), code: -32600, message: "Invalid Request: missing method" );
			return;
		}

		var id     = req.id     ?: nullValue();
		var method = req.method ?: "";
		var params = req.params ?: {};

		try {
			if ( method == "initialize" ) {
				handleInitialize( id, params );
			}
			else if ( method == "tools/list" ) {
				handleToolsList( id );
			}
			else if ( method == "tools/call" ) {
				handleToolsCall( id, params );
			}
			else {
				writeError( id: id, code: -32601, message: "Method not found: #method#" );
			}
		}
		catch ( any ex ) {
			systemOutput( ex, 1, 1 );
			writeError( id: id, code: -32603, message: "Internal error: #ex.message#" );
		}
	}

	// -------------------------------------------------------------------------
	// initialize - handshake, MCP clients send this on first connect
	// -------------------------------------------------------------------------
	private function handleInitialize( id, params ) {
		writeResult( id: arguments.id, result: {
			"protocolVersion": static.PROTOCOL_VERSION,
			"serverInfo"     : {
				"name"   : static.SERVER_NAME,
				"version": static.SERVER_VERSION
			},
			"capabilities": {
				"tools": {}
			}
		} );
	}

	// -------------------------------------------------------------------------
	// tools/list - return tool catalog
	// -------------------------------------------------------------------------
	private function handleToolsList( id ) {
		writeResult( id: arguments.id, result: {
			"tools": static.tools
		} );
	}

	// -------------------------------------------------------------------------
	// tools/call - execute a tool
	// -------------------------------------------------------------------------
	private function handleToolsCall( id, params ) {
		if ( !structKeyExists( params, "name" ) ) {
			writeError( id: arguments.id, code: -32602, message: "Invalid params: missing tool name" );
			return;
		}

		var toolName = params.name;
		var args     = params.arguments ?: {};

		if ( toolName == "get_lucee_function" ) {
			writeResult( id: arguments.id, result: toolGetLuceeFunction( args ) );
		}
		else if ( toolName == "get_lucee_tag" ) {
			writeResult( id: arguments.id, result: toolGetLuceeTag( args ) );
		}
		else {
			writeError( id: arguments.id, code: -32602, message: "Unknown tool: #toolName#" );
		}
	}

	// -------------------------------------------------------------------------
	// Tool: get_lucee_function
	// -------------------------------------------------------------------------
	private function toolGetLuceeFunction( args ) {
		if ( !structKeyExists( args, "name" ) || isEmpty( trim( args.name ) ) ) {
			cfthrow( message: "name is required" );
		}

		var name      = trim( args.name );
		var functions = getFunctionList();

		// case-insensitive lookup
		var matchKey = "";
		loop array=structKeyArray( functions ) item="local.k" {
			if ( compareNoCase( k, name ) == 0 ) {
				matchKey = k;
				break;
			}
		}

		if ( isEmpty( matchKey ) ) {
			return toTextContent( "Function '#name#' not found. Use search_lucee_docs to find available functions." );
		}

		var data = getFunctionData( matchKey );
		var text = "## Function #matchKey#"
		         & chr(10) & chr(10)
		         & "Documentation: https://docs.lucee.org/reference/functions/#lCase(matchKey)#.html"
		         & chr(10) & chr(10)
		         & "```json"
		         & chr(10)
		         & serializeJSON( data, false )
		         & chr(10)
		         & "```";

		return toTextContent( text );
	}

	// -------------------------------------------------------------------------
	// Tool: get_lucee_tag
	// -------------------------------------------------------------------------
	private function toolGetLuceeTag( args ) {
		if ( !structKeyExists( args, "name" ) || isEmpty( trim( args.name ) ) ) {
			cfthrow( message: "name is required" );
		}

		var name = lCase( trim( args.name ) );
		// strip leading cf prefix if supplied
		if ( left( name, 2 ) == "cf" ) name = mid( name, 3 );

		var tagList = getTagList();
		var matchPrefix = "";
		var matchName   = "";

		loop struct=tagList index="local.prefix" item="local.tags" {
			loop array=structKeyArray( tags ) item="local.k" {
				if ( compareNoCase( k, name ) == 0 ) {
					matchPrefix = prefix;
					matchName   = k;
					break;
				}
			}
			if ( !isEmpty( matchName ) ) break;
		}

		if ( isEmpty( matchName ) ) {
			return toTextContent( "Tag '#name#' not found. Use search_lucee_docs to find available tags." );
		}

		var data = getTagData( matchPrefix, matchName );
		var text = "## Tag #matchPrefix##matchName#"
		         & chr(10) & chr(10)
		         & "Documentation: https://docs.lucee.org/reference/tags/#lCase(matchName)#.html"
		         & chr(10) & chr(10)
		         & "```json"
		         & chr(10)
		         & serializeJSON( data, false )
		         & chr(10)
		         & "```";

		return toTextContent( text );
	}

	// -------------------------------------------------------------------------
	// Helper: wrap text in MCP content array format
	// -------------------------------------------------------------------------
	private static function toTextContent( string text ) {
		return {
			"content": [
				{
					"type": "text",
					"text": arguments.text
				}
			]
		};
	}

}
