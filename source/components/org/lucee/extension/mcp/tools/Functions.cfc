
component extends="Tool" accessors=true {

	variables.name="get_lucee_function";
	variables.description="Get the complete descriptor for a specific Lucee built-in function. 
		Returns argument names, types, descriptions and examples. Use this when you know the exact function name and need its full signature.";
	
	variables.inputSchema={
		"type"      : "object",
		"properties": {
			"name": {
				"type"       : "string",
				"description": "The function name, e.g. 'arraySort', 'listToArray', 'dateAdd'"
			}
		},
		"required": [ "name" ]
	};



	public function exec( required struct args ) {
		if ( !structKeyExists( args, "name" ) || isEmpty( trim( args.name ) ) ) {
			cfthrow( message: "name is required" );
		}
		var name = trim( args.name );


		if ( !structKeyExists(getFunctionList(), name ) ) {
			return toTextContent( "Function '#name#' not found. " );
		}

		var data = getFunctionData( name );
		var text = "## Function #name#"
		         & chr(10) & chr(10)
		         & "Documentation: https://docs.lucee.org/reference/functions/#lCase(name)#.html"
		         & chr(10) & chr(10)
		         & "```json"
		         & chr(10)
		         & serializeJSON( data, false )
		         & chr(10)
		         & "```";

		return toTextContent( text );
	}

}
