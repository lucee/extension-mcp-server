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
 * get_lucee_function and get_lucee_tag are always enabled. Other tools
 * (search_lucee_docs, parse_cfml_ast, query_cfml_ast, and any custom tools)
 * are disabled by default: omitted from tools/list, and tools/call returns
 * a JSON-RPC error. Enable them with the system property "lucee.mcp.extra.tools"
 * or the environment variable "LUCEE_MCP_EXTRA_TOOLS" set to true.
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
				ackNotification();
			}
			writeError( requestId, -32600, "Invalid Request: missing method" );
			return;
		}

		var method = req.method ?: "";
		var params = req.params ?: {};

		if ( isNotification( req ) ) {
			ackNotification();
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

	private function ackNotification() {
		setting show = false;
		cfheader( statusCode = 202 );
		abort;
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
		var list = variables.toolsIndex;
		if ( !isExtraToolsEnabled() ) {
			list = [];
			loop array=variables.toolsIndex item="local.tool" {
				if ( isCoreTool( tool.name ) ) arrayAppend( list, tool );
			}
		}
		writeResult( arguments.id, {
			"tools": list
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
		else if ( !isExtraToolsEnabled() && !isCoreTool( toolName ) ) {
			writeError( arguments.id, -32602, "Tool '#toolName#' is disabled" );
		}
		else {
			writeResult( arguments.id, tool.exec( args ) );
		}
	}

	/**
	 * Tools that stay available even when extra tools are disabled.
	 */
	private boolean function isCoreTool( required string name ) {
		return arguments.name == "get_lucee_function" || arguments.name == "get_lucee_tag";
	}

	/**
	 * Extra tools (docs search, AST, and any custom tools) are disabled by default.
	 * Enable them with the system property "lucee.mcp.extra.tools" or the
	 * environment variable "LUCEE_MCP_EXTRA_TOOLS" set to true.
	 */
	private boolean function isExtraToolsEnabled() {
		var sys = createObject( "java", "java.lang.System" );
		var raw = sys.getProperty( "lucee.mcp.extra.tools" )
		       ?: sys.getenv( "LUCEE_MCP_EXTRA_TOOLS" )
		       ?: "";
		raw = trim( raw );
		return isBoolean( raw ) && raw;
	}
}
