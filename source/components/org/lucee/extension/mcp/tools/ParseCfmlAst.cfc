/**
 * MCP Tool: parse_cfml_ast
 *
 * Parses CFML source code into an Abstract Syntax Tree using Lucee 7's astFromString.
 */
component extends="Tool" {

	variables.name        = "parse_cfml_ast";
	variables.description = "Parse CFML source code into an Abstract Syntax Tree (AST). "
	                    & "Returns a JSON tree with node types, source positions, function calls, tags, and control flow. "
	                    & "Requires Lucee 7.0.0.296+. Use for code analysis or as input to query_cfml_ast.";

	variables.inputSchema = {
		"type"      : "object",
		"properties": {
			"source": {
				"type"       : "string",
				"description": "CFML source code to parse"
			},
			"path": {
				"type"       : "string",
				"description": "Alternative to source: path to a .cfm/.cfc/.cfml file (prefer for components)"
			},
			"mode": {
				"type"       : "string",
				"enum"       : [ "tag", "script" ],
				"default"    : "tag",
				"description": "Parse as tag-based CFML (default) or CFScript"
			},
			"summary": {
				"type"       : "boolean",
				"default"    : false,
				"description": "If true, return a compact summary instead of the full AST"
			},
			"maxDepth": {
				"type"       : "integer",
				"description": "Optional: limit tree depth in output (ignored when summary=true)"
			}
		},
		"required": []
	};

	public function init() {
		variables.astSupport = createObject( "component", "org.lucee.extension.mcp.AstSupport" );
		return this;
	}

	public function exec( required struct args ) {
		if ( !variables.astSupport.isSupported() ) {
			return toTextContent( variables.astSupport.unsupportedMessage() );
		}

		var hasSource = structKeyExists( args, "source" ) && len( trim( args.source ) );
		var hasPath   = structKeyExists( args, "path" ) && len( trim( args.path ) );

		if ( !hasSource && !hasPath ) {
			cfthrow( message: "source or path is required" );
		}

		var ast = variables.astSupport.parse( args );

		if ( args.summary ?: false ) {
			return toTextContent( serializeJSON( variables.astSupport.summarize( ast ), false ) );
		}

		if ( structKeyExists( args, "maxDepth" ) && val( args.maxDepth ) > 0 ) {
			ast = variables.astSupport.pruneTree( ast, val( args.maxDepth ) );
		}

		return toTextContent( serializeJSON( ast, false ) );
	}

}
