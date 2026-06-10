/**
 * Shared AST parsing and tree-walking utilities for MCP AST tools.
 */
component {

	function isSupported() {
		return structKeyExists( getFunctionList(), "astFromString" );
	}

	function unsupportedMessage() {
		return "AST parsing requires Lucee 7.0.0.296 or later (astFromString / astFromPath).";
	}

	function parse( required struct opts ) {
		if ( structKeyExists( opts, "path" ) && len( trim( opts.path ) ) ) {
			return astFromPath( trim( opts.path ) );
		}
		if ( !structKeyExists( opts, "source" ) || isEmpty( trim( opts.source ) ) ) {
			cfthrow( message: "source or path is required" );
		}
		return astFromString( trim( opts.source ), opts.mode ?: "tag" );
	}

	function pruneTree( required struct node, required numeric maxDepth, numeric depth = 0 ) {
		if ( depth >= maxDepth ) {
			return { "type": node.type ?: "Unknown", "pruned": true };
		}

		var result = { "type": node.type };
		if ( structKeyExists( node, "start" ) ) result.start = node.start;
		if ( structKeyExists( node, "end" ) ) result.end = node.end;

		for ( var key in node ) {
			if ( listFindNoCase( "type,start,end", key ) ) continue;

			var val = node[ key ];
			if ( isArray( val ) ) {
				result[ key ] = val.map( function( item ) {
					if ( isStruct( item ) && structKeyExists( item, "type" ) ) {
						return pruneTree( item, maxDepth, depth + 1 );
					}
					return item;
				} );
			} else if ( isStruct( val ) && structKeyExists( val, "type" ) ) {
				result[ key ] = pruneTree( val, maxDepth, depth + 1 );
			} else {
				result[ key ] = val;
			}
		}

		return result;
	}

	function findNodes( required struct root, struct filter = {} ) {
		var matches = [];
		walkValue( root, function( node ) {
			if ( matchesFilter( node, filter ) ) {
				arrayAppend( matches, node );
			}
		} );
		return matches;
	}

	function summarize( required struct ast ) {
		var summary = {
			"type"      : ast.type ?: "Program",
			"functions" : [],
			"tags"      : [],
			"calls"     : []
		};
		var seenTags  = {};
		var seenCalls = {};

		walkValue( ast, function( node ) {
			if ( node.type == "FunctionDeclaration" && structKeyExists( node, "name" ) ) {
				arrayAppend( summary.functions, {
					"name"  : node.name,
					"access": node.access ?: "",
					"line"  : node.start.line ?: 0
				} );
			}
			if ( node.type == "CFMLTag" ) {
				var tagName = lCase( node.fullname ?: node.name ?: "" );
				if ( len( tagName ) && !structKeyExists( seenTags, tagName ) ) {
					seenTags[ tagName ] = true;
					arrayAppend( summary.tags, {
						"name"    : tagName,
						"builtIn" : node.isBuiltIn ?: false,
						"line"    : node.start.line ?: 0
					} );
				}
			}
			if ( node.type == "CallExpression" ) {
				var callName = getCallName( node );
				if ( len( callName ) ) {
					var callKey = lCase( callName ) & "|" & ( node.start.line ?: 0 );
					if ( !structKeyExists( seenCalls, callKey ) ) {
						seenCalls[ callKey ] = true;
						arrayAppend( summary.calls, {
							"name"    : callName,
							"builtIn" : node.isBuiltIn ?: false,
							"line"    : node.start.line ?: 0
						} );
					}
				}
			}
		} );

		return summary;
	}

	private function walkValue( required any val, required function visitor ) {
		if ( isStruct( val ) ) {
			if ( structKeyExists( val, "type" ) ) {
				visitor( val );
			}
			for ( var key in val ) {
				walkValue( val[ key ], visitor );
			}
		} else if ( isArray( val ) ) {
			for ( var item in val ) {
				walkValue( item, visitor );
			}
		}
	}

	private function matchesFilter( required struct node, required struct filter ) {
		if ( structKeyExists( filter, "nodeType" ) && len( filter.nodeType ) ) {
			if ( node.type != filter.nodeType ) return false;
		}

		if ( structKeyExists( filter, "name" ) && len( filter.name ) ) {
			if ( !nodeMatchesName( node, filter.name ) ) return false;
		}

		if ( structKeyExists( filter, "builtInOnly" ) && filter.builtInOnly ) {
			if ( !( node.isBuiltIn ?: false ) ) return false;
		}

		if ( structKeyExists( filter, "line" ) && val( filter.line ) > 0 ) {
			if ( !nodeContainsLine( node, val( filter.line ) ) ) return false;
		}

		return true;
	}

	private function nodeMatchesName( required struct node, required string name ) {
		var needle = lCase( trim( name ) );

		if ( node.type == "CallExpression" ) {
			return lCase( getCallName( node ) ) == needle;
		}
		if ( node.type == "CFMLTag" ) {
			return lCase( node.name ?: "" ) == needle
			    || lCase( node.fullname ?: "" ) == needle;
		}
		if ( node.type == "FunctionDeclaration" && structKeyExists( node, "name" ) ) {
			return lCase( node.name ) == needle;
		}
		if ( node.type == "Identifier" && structKeyExists( node, "name" ) ) {
			return lCase( node.name ) == needle;
		}

		return false;
	}

	private function getCallName( required struct node ) {
		if ( !structKeyExists( node, "callee" ) || !isStruct( node.callee ) ) return "";
		if ( structKeyExists( node.callee, "name" ) ) return node.callee.name;
		if ( node.callee.type == "MemberExpression" && structKeyExists( node.callee, "property" ) ) {
			if ( isStruct( node.callee.property ) && structKeyExists( node.callee.property, "name" ) ) {
				return node.callee.property.name;
			}
		}
		return "";
	}

	private function nodeContainsLine( required struct node, required numeric line ) {
		if ( !structKeyExists( node, "start" ) || !structKeyExists( node, "end" ) ) return false;
		var startLine = val( node.start.line ?: 0 );
		var endLine   = val( node.end.line ?: startLine );
		return line >= startLine && line <= endLine;
	}

}
