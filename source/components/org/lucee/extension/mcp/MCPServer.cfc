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
 */
component extends="MCPSupport" {

	// MCP protocol version this server targets
	static.PROTOCOL_VERSION = "2024-11-05";
	static.SERVER_NAME       = "lucee-docs";
	static.SERVER_VERSION    = server.lucee.version;


	// -------------------------------------------------------------------------
	// Init
	// -------------------------------------------------------------------------
	public function init() {
 
		// get all Tools from the tools package
		variables.tools={};
		variables.toolsIndex=[];
		loop array=componentListPackage("org.lucee.extension.mcp.tools") item="local.name" {
			var meta=getComponentMetadata("org.lucee.extension.mcp.tools.#name#");
			if((meta.abstract?:false)==true) continue;
			
			var cfc=createObject("component","org.lucee.extension.mcp.tools.#name#");
			if(!isInstanceOf(cfc,"org.lucee.extension.mcp.tools.Tool"))  continue;
			if(structKeyExists(cfc,"init")) cfc.init();
			variables.tools[cfc.getName()]=cfc;
			arrayAppend(toolsIndex,
				[
					"name":cfc.getName(),
					"description":cfc.getDescription(),
					"inputSchema":cfc.getInputSchema()
				]
			);
		}
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
		writeResult( id: arguments.id, result: [
			"protocolVersion": static.PROTOCOL_VERSION,
			"serverInfo"     : [
				"name"   : static.SERVER_NAME,
				"version": static.SERVER_VERSION
			],
			"capabilities": [
				"tools": [:]
			]
		] );
	}

	// -------------------------------------------------------------------------
	// tools/list - return tool catalog
	// -------------------------------------------------------------------------
	public function handleToolsList( id ) {
		writeResult( id: arguments.id, result: {
			"tools": variables.toolsIndex
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

		var tool=variables.tools[toolName]?:nullValue();
		if(isNull(tool)) {
			writeError( id: arguments.id, code: -32602, message: "Unknown tool: #toolName#" );
		}
		else {
			writeResult( id: arguments.id, result: tool.exec( args ) );
		}
	}
}
