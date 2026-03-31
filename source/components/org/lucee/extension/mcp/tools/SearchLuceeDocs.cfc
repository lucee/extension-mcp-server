/**
 * MCP Tool: search_lucee_docs
 *
 * Searches Lucee documentation (functions, tags and recipes) using Lucene
 * full-text search and returns the most relevant passages as context.
 *
 * Requires the Lucee Lucene 3 extension (EFDEB172-F52E-4D84-9CD1A1F561B3DFC8).
 * If the extension is not installed the tool returns a graceful message.
 */
component extends="Tool" {

	variables.name        = "search_lucee_docs";
	variables.description = "Search Lucee documentation across functions, tags and recipes. "
	                      & "Returns the most relevant documentation passages for a given query. "
	                      & "Use this when you need to look up how something works in Lucee CFML.";

	variables.inputSchema = {
		"type"      : "object",
		"properties": {
			"query": {
				"type"       : "string",
				"description": "The search query, e.g. 'how to read a file', 'arraySort', 'cfquery tag'"
			},
			"maxResults": {
				"type"       : "integer",
				"description": "Maximum number of results to return (default: 3, max: 10)",
				"default"    : 3
			}
		},
		"required": [ "query" ]
	};

	// Lucene extension UUID
	static.LUCENE_EXT_ID   = "EFDEB172-F52E-4D84-9CD1A1F561B3DFC8";
	static.COLLECTION_NAME = "luceeai";

	// -------------------------------------------------------------------------

	public function exec( required struct args ) {
		if ( !structKeyExists( args, "query" ) || isEmpty( trim( args.query ) ) ) {
			cfthrow( message: "query is required" );
		}

		if ( !searchSupported() ) {
			return toTextContent( "Search is not available: Lucene 3 extension is not installed." );
		}

		var query      = trim( args.query );
		var maxResults = min( val( args.maxResults ?: 3 ), 10 );
		if ( maxResults < 1 ) maxResults = 3;

		createIndex();

		// Escape Lucene special characters
		var safeQuery = reReplace( query, "([+\-&|!(){}[\]^""~*?:\\/])", "\\\1", "ALL" );

		cfsearch(
			contextpassages      = 3
			contextHighlightBegin= ""
			contextHighlightEnd  = ""
			contextBytes         = 3000
			contextpassageLength = 1000
			name                 = "local.results"
			collection           = static.COLLECTION_NAME
			criteria             = safeQuery
			suggestions          = "always"
			maxrows              = maxResults
		);

		if ( results.recordCount == 0 ) {
			return toTextContent( "No documentation found for: #query#" );
		}

		var output = [];
		loop query=results {
			var passages = [];
			loop query=results.context.passages {
				arrayAppend( passages, {
					"start": results.context.passages.start,
					"end"  : results.context.passages.end,
					"score": results.context.passages.score,
					"data" : results.context.passages.original
				});
			}

			var src = results.custom2;
			src = replace( src,
				"https://raw.githubusercontent.com/lucee/lucee-docs/master/",
				"https://github.com/lucee/lucee-docs/blob/master/",
				"one"
			);

			arrayAppend( output, {
				"title"   : results.title,
				"summary" : results.summary,
				"keywords": results.custom1,
				"source"  : src,
				"score"   : results.score,
				"rank"    : results.rank,
				"content" : passages
			});
		}

		return toTextContent( serializeJSON( output, false ) );
	}

	// -------------------------------------------------------------------------
	// Index management
	// -------------------------------------------------------------------------

	private function createIndex() {
		createCollection();

		// Load all data sources
		var sources = [
			{ "name": "function", "data": getFunctionIndexData() },
			{ "name": "tag",      "data": getTagIndexData() },
			{ "name": "recipe",   "data": getRecipeIndexData() }
		];

		cfindex( action="list", name="local.existing", collection=static.COLLECTION_NAME );

		loop array=sources item="local.src" {
			var hash = "hash:#src.hash#";
			var alreadyIndexed = false;

			loop query=existing {
				if ( existing.custom4 == hash ) {
					alreadyIndexed = true;
					break;
				}
			}

			if ( !alreadyIndexed ) {
				cfindex(
					action     = "update"
					type       = "custom"
					collection = static.COLLECTION_NAME
					key        = "url"
					title      = "title"
					body       = src.bodyColumns
					custom1    = "keywords"
					custom2    = "url"
					custom4    = hash
					query      = src.name
				);
			}
		}
	}

	private function createCollection() {
		cfcollection( action="list", name="local.cols" );
		loop query=cols {
			if ( cols.name == static.COLLECTION_NAME ) return;
		}
		try {
			var dir = expandPath( "{lucee-config-dir}/doc/search" );
			if ( !directoryExists( dir ) ) directoryCreate( dir, true );
		} catch( any e ) {
			var dir = expandPath( "{temp-directory}" );
		}
		cfcollection( action="create", collection=static.COLLECTION_NAME, path=dir );
	}

	private function searchSupported() {
		if ( !extensionExists( static.LUCENE_EXT_ID ) ) return false;
		var info = extensionInfo( static.LUCENE_EXT_ID );
		return listFirst( info.version, "." ) >= 3;
	}

	// -------------------------------------------------------------------------
	// Data loaders - return struct with keys: name, hash, bodyColumns, + query variable
	// -------------------------------------------------------------------------

	private function getFunctionIndexData() {
		var qry = queryNew( [ "title", "body", "url", "keywords" ] );

		loop array=structKeyArray( getFunctionList() ) item="local.fnName" {
			var data = getFunctionData( fnName );
			var row  = queryAddRow( qry );
			var body = trim( "
## Function #fnName#

Json function library descriptor for the function #fnName#

documentation: https://docs.lucee.org/reference/functions/#fnName#.html

```json
#serializeJSON( var:data, compact:false )#
```
			" );
			querySetCell( qry, "title",    fnName, row );
			querySetCell( qry, "body",     body,   row );
			querySetCell( qry, "url",      "https://docs.lucee.org/reference/functions/#lCase(fnName)#.html", row );
			querySetCell( qry, "keywords", "function,#lCase(fnName)#", row );
		}

		variables.function = qry;
		return {
			"name"       : "function",
			"hash"       : hash( qry.recordCount, "quick" ),
			"bodyColumns": "body"
		};
	}

	private function getTagIndexData() {
		var qry = queryNew( [ "title", "body", "url", "keywords" ] );

		loop struct=getTagList() index="local.prefix" item="local.tags" {
			loop array=structKeyArray( tags ) item="local.tagName" {
				var data = getTagData( prefix, tagName );
				var row  = queryAddRow( qry );
				var body = trim( "
## Tag #prefix##tagName#

Json tag library descriptor for the tag #prefix##tagName#

documentation: https://docs.lucee.org/reference/tags/#tagName#.html

```json
#serializeJSON( var:data, compact:false )#
```
				" );
				querySetCell( qry, "title",    "#prefix##tagName#", row );
				querySetCell( qry, "body",     body,                row );
				querySetCell( qry, "url",      "https://docs.lucee.org/reference/tags/#lCase(tagName)#.html", row );
				querySetCell( qry, "keywords", "tag,#lCase(tagName)#", row );
			}
		}

		variables.tag = qry;
		return {
			"name"       : "tag",
			"hash"       : hash( qry.recordCount, "quick" ),
			"bodyColumns": "body"
		};
	}

	private function getRecipeIndexData() {
		var rootPath = server.system.environment.LUCEE_DOC_RECIPES_PATH
		             ?: "https://raw.githubusercontent.com/lucee/lucee-docs/master";

		// fetch remote index
		http url="#rootPath#/docs/recipes/index.json" timeout=10 result="local.res";
		if ( res.status_code < 200 || res.status_code >= 300 ) {
			// nothing to index
			variables.recipe = queryNew( [ "title", "content", "url", "keywords" ] );
			return { "name": "recipe", "hash": "empty", "bodyColumns": "content,keywords" };
		}

		var index = deserializeJSON( res.filecontent );
		var qry   = queryNew( [ "title", "content", "url", "keywords" ] );

		loop array=index item="local.entry" {
			var url     = rootPath & entry.path;
			var content = "";

			http url=url timeout=10 result="local.recipeRes";
			if ( recipeRes.status_code >= 200 && recipeRes.status_code < 300 ) {
				// strip front matter comment block
				var raw      = recipeRes.filecontent;
				var endIndex = find( "-->", raw, 4 );
				content = endIndex > 0 ? trim( mid( raw, endIndex + 3 ) ) : trim( raw );
			}

			if ( !isEmpty( content ) ) {
				var row = queryAddRow( qry );
				var src = replace( url,
					"https://raw.githubusercontent.com/lucee/lucee-docs/master/",
					"https://github.com/lucee/lucee-docs/blob/master/",
					"one"
				);
				var keywords = isArray( entry.keywords ?: "" )
				             ? arrayToList( entry.keywords )
				             : ( entry.keywords ?: "" );

				querySetCell( qry, "title",    entry.title ?: "",  row );
				querySetCell( qry, "content",  content,            row );
				querySetCell( qry, "url",      src,                row );
				querySetCell( qry, "keywords", keywords,           row );
			}
		}

		variables.recipe = qry;
		return {
			"name"       : "recipe",
			"hash"       : hash( res.filecontent, "md5" ),
			"bodyColumns": "content,keywords"
		};
	}

}
