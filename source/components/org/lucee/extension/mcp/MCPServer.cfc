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
		var requestId = getRpcRequestId( req );

		if ( !structKeyExists( req, "method" ) ) {
			if ( isNotification( req ) ) {
				writeNotificationAck();
			}
			writeError( requestId, -32600, "Invalid Request: missing method" );
			return;
		}

		var method = req.method ?: "";
		var params = req.params ?: {};

		if ( isNotification( req ) ) {
			writeNotificationAck();
		}

		try {
			if ( method == "initialize" ) {
				handleInitialize( requestId, params );
			}
			else if ( method == "tools/list" ) {
				handleToolsList( requestId );
			}
			else if ( method == "tools/call" ) {
				handleToolsCall( requestId, params );
			}
			else {
				writeError( requestId, -32601, "Method not found: " & method );
			}
		}
		catch ( any ex ) {
			writeError( requestId, -32603, "Internal error: " & ex.message );
		}
	}

	// -------------------------------------------------------------------------
	// initialize - handshake, MCP clients send this on first connect
	// -------------------------------------------------------------------------
	private function handleInitialize( id, params ) {
		writeResult( arguments.id, [
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
		writeResult( arguments.id, {
			"tools": variables.toolsIndex
		} );
	}

	// -------------------------------------------------------------------------
	// tools/call - execute a tool
	// -------------------------------------------------------------------------
	private function handleToolsCall( id, params ) {
		if ( !structKeyExists( params, "name" ) ) {
			writeError( arguments.id, -32602, "Invalid params: missing tool name" );
			return;
		}

		var toolName = params.name;
		var args     = params.arguments ?: {};

		var tool=variables.tools[toolName]?:nullValue();
		if(isNull(tool)) {
			writeError( arguments.id, -32602, "Unknown tool: #toolName#" );
		}
		else {
			writeResult( arguments.id, tool.exec( args ) );
		}
	}
}
