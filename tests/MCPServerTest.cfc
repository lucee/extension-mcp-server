<!--- 
*
* Copyright (c) 2026, Lucee Association Switzerland. All rights reserved.
*
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either 
* version 2.1 of the License, or (at your option) any later version.
* 
* This library is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* Lesser General Public License for more details.
* 
* You should have received a copy of the GNU Lesser General Public 
* License along with this library.  If not, see <http://www.gnu.org/licenses/>.
* 
---><cfscript>
component extends="org.lucee.cfml.test.LuceeTestCase" labels="mcpserver" {

	function beforeAll() {
	}

	function afterAll() {
	}

	// -------------------------------------------------------------------------
	// Helper: POST JSON-RPC request internally, return parsed response struct
	// -------------------------------------------------------------------------
	private function post( required struct body ) {
		var res = internalRequest(
			template : "/lucee/mcp/index.cfm",
			method   : "POST",
			headers  : { "Content-Type": "application/json" },
			body     : serializeJSON( arguments.body ),
			throwonerror: false
		);
		return deserializeJSON( res.filecontent );
	}

	function run( testResults, testBox ) {

		// -------------------------------------------------------------------------
		describe( "initialize", function() {

			it( "returns jsonrpc 2.0", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":1, "method":"initialize", "params":{} });
				expect( rsp.jsonrpc ).toBe( "2.0" );
			});

			it( "echoes the request id", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":1, "method":"initialize", "params":{} });
				expect( rsp.id ).toBe( 1 );
			});

			it( "returns protocolVersion", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":1, "method":"initialize", "params":{} });
				expect( structKeyExists( rsp.result, "protocolVersion" ) ).toBeTrue();
			});

			it( "returns serverInfo.name as lucee-docs", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":1, "method":"initialize", "params":{} });
				expect( rsp.result.serverInfo.name ).toBe( "lucee-docs" );
			});

			it( "returns non-empty serverInfo.version", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":1, "method":"initialize", "params":{} });
				expect( isEmpty( rsp.result.serverInfo.version ) ).toBeFalse();
			});

			it( "returns tools capability", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":1, "method":"initialize", "params":{} });
				expect( structKeyExists( rsp.result.capabilities, "tools" ) ).toBeTrue();
			});

		});

		// -------------------------------------------------------------------------
		describe( "tools/list", function() {

			it( "returns a tools array", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":2, "method":"tools/list" });
				expect( isArray( rsp.result.tools ) ).toBeTrue();
			});

			it( "returns exactly 2 tools", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":2, "method":"tools/list" });
				expect( arrayLen( rsp.result.tools ) ).toBe( 2 );
			});

			it( "includes get_lucee_function", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":2, "method":"tools/list" });
				var names = rsp.result.tools.map( function(t){ return t.name; } );
				expect( arrayFind( names, "get_lucee_function" ) > 0 ).toBeTrue();
			});

			it( "includes get_lucee_tag", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":2, "method":"tools/list" });
				var names = rsp.result.tools.map( function(t){ return t.name; } );
				expect( arrayFind( names, "get_lucee_tag" ) > 0 ).toBeTrue();
			});

			it( "each tool has an inputSchema", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":2, "method":"tools/list" });
				for ( var tool in rsp.result.tools ) {
					expect( structKeyExists( tool, "inputSchema" ) ).toBeTrue();
				}
			});

		});

		// -------------------------------------------------------------------------
		describe( "tools/call — get_lucee_function", function() {

			it( "returns content array for known function", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":3, "method":"tools/call",
					"params": { "name":"get_lucee_function", "arguments":{ "name":"arraySort" } } });
				expect( isArray( rsp.result.content ) ).toBeTrue();
			});

			it( "content contains the function name", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":3, "method":"tools/call",
					"params": { "name":"get_lucee_function", "arguments":{ "name":"arraySort" } } });
				expect( findNoCase( "arraySort", rsp.result.content[1].text ) > 0 ).toBeTrue();
			});

			it( "content contains docs URL", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":3, "method":"tools/call",
					"params": { "name":"get_lucee_function", "arguments":{ "name":"arraySort" } } });
				expect( findNoCase( "docs.lucee.org", rsp.result.content[1].text ) > 0 ).toBeTrue();
			});

			it( "lookup is case-insensitive", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":4, "method":"tools/call",
					"params": { "name":"get_lucee_function", "arguments":{ "name":"ARRAYSORT" } } });
				expect( findNoCase( "arraySort", rsp.result.content[1].text ) > 0 ).toBeTrue();
			});

			it( "unknown function returns content with not-found message", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":5, "method":"tools/call",
					"params": { "name":"get_lucee_function", "arguments":{ "name":"doesNotExistXYZ" } } });
				expect( isArray( rsp.result.content ) ).toBeTrue();
				expect( findNoCase( "not found", rsp.result.content[1].text ) > 0 ).toBeTrue();
			});

			it( "missing name argument returns error", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":6, "method":"tools/call",
					"params": { "name":"get_lucee_function", "arguments":{} } });
				expect( structKeyExists( rsp, "error" ) ).toBeTrue();
			});

		});

		// -------------------------------------------------------------------------
		describe( "tools/call — get_lucee_tag", function() {

			it( "returns content array for known tag", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":7, "method":"tools/call",
					"params": { "name":"get_lucee_tag", "arguments":{ "name":"query" } } });
				expect( isArray( rsp.result.content ) ).toBeTrue();
			});

			it( "content contains the tag name", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":7, "method":"tools/call",
					"params": { "name":"get_lucee_tag", "arguments":{ "name":"query" } } });
				expect( findNoCase( "query", rsp.result.content[1].text ) > 0 ).toBeTrue();
			});

			it( "content contains docs URL", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":7, "method":"tools/call",
					"params": { "name":"get_lucee_tag", "arguments":{ "name":"query" } } });
				expect( findNoCase( "docs.lucee.org", rsp.result.content[1].text ) > 0 ).toBeTrue();
			});

			it( "cf prefix is stripped automatically", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":8, "method":"tools/call",
					"params": { "name":"get_lucee_tag", "arguments":{ "name":"cfquery" } } });
				expect( findNoCase( "query", rsp.result.content[1].text ) > 0 ).toBeTrue();
			});

			it( "unknown tag returns content with not-found message", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":9, "method":"tools/call",
					"params": { "name":"get_lucee_tag", "arguments":{ "name":"doesNotExistXYZ" } } });
				expect( isArray( rsp.result.content ) ).toBeTrue();
				expect( findNoCase( "not found", rsp.result.content[1].text ) > 0 ).toBeTrue();
			});

			it( "missing name argument returns error", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":10, "method":"tools/call",
					"params": { "name":"get_lucee_tag", "arguments":{} } });
				expect( structKeyExists( rsp, "error" ) ).toBeTrue();
			});

		});

		// -------------------------------------------------------------------------
		describe( "JSON-RPC protocol errors", function() {

			it( "GET request returns error -32600", function() {
				var res = internalRequest( template: "/lucee/mcp/index.cfm", method: "GET", throwonerror: false );
				var body = deserializeJSON( res.filecontent );
				expect( body.error.code ).toBe( -32600 );
			});

			it( "empty POST body returns error -32700", function() {
				var res = internalRequest(
					template     : "/lucee/mcp/index.cfm",
					method       : "POST",
					headers      : { "Content-Type": "application/json" },
					throwonerror : false
				);
				var body = deserializeJSON( res.filecontent );
				expect( body.error.code ).toBe( -32700 );
			});

			it( "missing method field returns -32600", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":11 });
				expect( rsp.error.code ).toBe( -32600 );
			});

			it( "unknown method returns -32601", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":12, "method":"foo/bar" });
				expect( rsp.error.code ).toBe( -32601 );
			});

			it( "unknown tool name returns -32602", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":13, "method":"tools/call",
					"params": { "name":"non_existent_tool", "arguments":{} } });
				expect( rsp.error.code ).toBe( -32602 );
			});

			it( "tools/call without name param returns -32602", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":14, "method":"tools/call", "params":{} });
				expect( rsp.error.code ).toBe( -32602 );
			});

			it( "string id is echoed back correctly", function() {
				var rsp = post({ "jsonrpc":"2.0", "id":"abc-123", "method":"tools/list" });
				expect( rsp.id ).toBe( "abc-123" );
			});

		});

	}
}
</cfscript>
