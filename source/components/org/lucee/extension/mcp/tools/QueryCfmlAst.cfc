/**
 * MCP Tool: query_cfml_ast
 *
 * Parses CFML and returns AST nodes matching type, name, line, or built-in filters.
 */
component extends="Tool" {

	variables.name        = "query_cfml_ast";
	variables.description = "Query CFML source for AST nodes by type, name, line number, or built-in status. "
	                    & "Use to find function calls, tags, UDF definitions, or nodes at a specific line. "
	                    & "Requires Lucee 7.0.0.296+.";

	variables.inputSchema = {
		"type"      : "object",
		"properties": {
			"source": {
				"type"       : "string",
				"description": "CFML source code to analyze"
			},
			"path": {
				"type"       : "string",
				"description": "Alternative to source: path to a .cfm/.cfc/.cfml file"
			},
			"mode": {
				"type"       : "string",
				"enum"       : [ "tag", "script" ],
				"default"    : "tag",
				"description": "Parse as tag-based CFML (default) or CFScript"
			},
			"nodeType": {
				"type"       : "string",
				"description": "Filter by node type: CallExpression, CFMLTag, FunctionDeclaration, IfStatement, etc."
			},
			"name": {
				"type"       : "string",
				"description": "Filter CallExpression callees, CFMLTag names, or FunctionDeclaration names (case-insensitive)"
			},
			"builtInOnly": {
				"type"       : "boolean",
				"description": "If true, only return nodes where isBuiltIn=true"
			},
			"line": {
				"type"       : "integer",
				"description": "Return nodes whose source range includes this line number"
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
		var filter = {};

		if ( structKeyExists( args, "nodeType" ) && len( trim( args.nodeType ) ) ) {
			filter.nodeType = trim( args.nodeType );
		}
		if ( structKeyExists( args, "name" ) && len( trim( args.name ) ) ) {
			filter.name = trim( args.name );
		}
		if ( args.builtInOnly ?: false ) {
			filter.builtInOnly = true;
		}
		if ( structKeyExists( args, "line" ) && val( args.line ) > 0 ) {
			filter.line = val( args.line );
		}

		var matches = variables.astSupport.findNodes( ast, filter );

		return toTextContent( serializeJSON( {
			"matchCount": arrayLen( matches ),
			"matches"   : matches
		}, false ) );
	}

}
