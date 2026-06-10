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
        variables.tool = createObject( "component", "org.lucee.extension.mcp.tools.QueryCfmlAst" );
        variables.tool.init();
        variables.astSupported = structKeyExists( getFunctionList(), "astFromString" );
    }

    function run( testResults, testBox ) {

        describe( "checking the QueryCfmlAst tool", function() {

            it( "checking name", function() {
                expect( tool.getName() ).toBe( "query_cfml_ast" );
            });

            it( "checking description", function() {
                expect( len( tool.getDescription() ) > 0 ).toBeTrue();
            });

            it( "checking inputSchema", function() {
                var schema = tool.getInputSchema();
                expect( schema.type ).toBe( "object" );
                expect( structKeyExists( schema.properties, "nodeType" ) ).toBeTrue();
                expect( structKeyExists( schema.properties, "name" ) ).toBeTrue();
                expect( structKeyExists( schema.properties, "builtInOnly" ) ).toBeTrue();
            });

            it( "missing source and path returns error", function() {
                expect( function() {
                    tool.exec( {} );
                } ).toThrow();
            });

            it( "finds CFMLTag nodes by name", function() {
                if ( !astSupported ) return;

                var result = tool.exec( {
                    source  : '<cfloop from="1" to="10" index="i"></cfloop>',
                    nodeType: "CFMLTag",
                    name    : "loop"
                } );
                var data = deserializeJSON( result.content[1].text );

                expect( data.matchCount ).toBeGT( 0 );
                expect( data.matches[1].type ).toBe( "CFMLTag" );
                expect( lCase( data.matches[1].name ) ).toBe( "loop" );
            });

            it( "finds built-in CallExpression nodes", function() {
                if ( !astSupported ) return;

                var result = tool.exec( {
                    source     : '<cfscript>len("abc");</cfscript>',
                    nodeType   : "CallExpression",
                    builtInOnly: true
                } );
                var data = deserializeJSON( result.content[1].text );

                expect( data.matchCount ).toBeGT( 0 );
                expect( data.matches[1].isBuiltIn ).toBeTrue();
            });

            it( "finds nodes at a line number", function() {
                if ( !astSupported ) return;

                var result = tool.exec( {
                    source: '<cfset x = 1>',
                    line  : 1
                } );
                var data = deserializeJSON( result.content[1].text );

                expect( data.matchCount ).toBeGT( 0 );
            });

        });
    }
}
</cfscript>
