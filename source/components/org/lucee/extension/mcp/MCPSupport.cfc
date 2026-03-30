/**
 * Base support component for the MCP server.
 * Handles JSON-RPC 2.0 request reading, response writing and error formatting.
 * Mirrors the pattern established in AISupport.cfc.
 */
abstract component {

	/**
	 * Read and parse the incoming JSON-RPC request body.
	 * Returns a struct with id, method, params.
	 */
	package static function readRequest() {
		var data = getHTTPRequestData();

		if ( data.method != "POST" ) {
			writeError(
				id      : nullValue(),
				code    : -32600,
				message : "Invalid Request: only POST is supported"
			);
			abort;
		}

		if ( !structKeyExists( data, "content" ) || isEmpty( trim( data.content ) ) ) {
			writeError(
				id      : nullValue(),
				code    : -32700,
				message : "Parse error: empty request body"
			);
			abort;
		}

		try {
			return deserializeJSON( data.content );
		}
		catch ( any ex ) {
			writeError(
				id      : nullValue(),
				code    : -32700,
				message : "Parse error: #ex.message#"
			);
			abort;
		}
	}

	/**
	 * Write a successful JSON-RPC response.
	 */
	package static function writeResult( id, result ) {
		setting show = false;
		content type="application/json;charset=UTF-8";
		echo( serializeJSON( {
			"jsonrpc" : "2.0",
			"id"      : arguments.id,
			"result"  : arguments.result
		} ) );
	}

	/**
	 * Write a JSON-RPC error response.
	 * Standard codes: -32700 parse error, -32600 invalid request,
	 *                 -32601 method not found, -32602 invalid params
	 */
	package static function writeError( id, numeric code, string message ) {
		setting show = false;
		content type="application/json;charset=UTF-8";
		echo( serializeJSON( {
			"jsonrpc" : "2.0",
			"id"      : arguments.id,
			"error"   : {
				"code"    : arguments.code,
				"message" : arguments.message
			}
		} ) );
	}

}
