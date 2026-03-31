
component extends="Tool" {

	variables.name="get_lucee_tag";
	variables.description="Get the complete descriptor for a specific Lucee tag. 
		Returns attribute names, types, descriptions and examples. Use this when you know the exact tag name and need its full specification.";
	
	variables.inputSchema={
		"type"      : "object",
		"properties": {
			"name": {
				"type"       : "string",
				"description": "The tag name without prefix, e.g. 'query', 'loop', 'http'"
			}
		},
		"required": [ "name" ]
	};


	public function exec( required struct args ) {
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
				// TODO unnecessry lucee is not case sensitive
				if ( compareNoCase( k, name ) == 0 ) {
					matchPrefix = prefix;
					matchName   = k;
					break;
				}
			}
			if ( !isEmpty( matchName ) ) break;
		}

		if ( isEmpty( matchName ) ) {
			return toTextContent( "Tag '#name#' not found. " );
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
}
