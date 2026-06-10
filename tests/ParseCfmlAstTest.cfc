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
        variables.tool = createObject( "component", "org.lucee.extension.mcp.tools.ParseCfmlAst" );
        variables.tool.init();
        variables.astSupported = structKeyExists( getFunctionList(), "astFromString" );
    }

    function run( testResults, testBox ) {

        describe( "checking the ParseCfmlAst tool", function() {

            it( "checking name", function() {
                expect( tool.getName() ).toBe( "parse_cfml_ast" );
            });

            it( "checking description", function() {
                expect( len( tool.getDescription() ) > 0 ).toBeTrue();
            });

            it( "checking inputSchema", function() {
                var schema = tool.getInputSchema();
                expect( schema.type ).toBe( "object" );
                expect( structKeyExists( schema.properties, "source" ) ).toBeTrue();
                expect( structKeyExists( schema.properties, "path" ) ).toBeTrue();
                expect( structKeyExists( schema.properties, "mode" ) ).toBeTrue();
                expect( structKeyExists( schema.properties, "summary" ) ).toBeTrue();
            });

            it( "missing source and path returns error", function() {
                expect( function() {
                    tool.exec( {} );
                } ).toThrow();
            });

            it( "returns unsupported message on older Lucee", function() {
                if ( astSupported ) return;

                var result = tool.exec( { source: '<cfset x = 1>' } );
                expect( findNoCase( "requires Lucee", result.content[1].text ) > 0 ).toBeTrue();
            });

            it( "parses tag-based CFML", function() {
                if ( !astSupported ) return;

                var result = tool.exec( { source: '<cfset x = 1>' } );
                var ast = deserializeJSON( result.content[1].text );

                expect( ast.type ).toBe( "Program" );
                expect( isArray( ast.body ) ).toBeTrue();
                expect( arrayLen( ast.body ) ).toBeGT( 0 );
            });

            it( "summary mode returns compact digest", function() {
                if ( !astSupported ) return;

                var source = '<cfscript>len("a");</cfscript><cfloop from="1" to="2" index="i"></cfloop>';
                var result = tool.exec( { source: source, summary: true } );
                var summary = deserializeJSON( result.content[1].text );

                expect( structKeyExists( summary, "calls" ) ).toBeTrue();
                expect( structKeyExists( summary, "tags" ) ).toBeTrue();
                expect( arrayLen( summary.calls ) ).toBeGT( 0 );
                expect( arrayLen( summary.tags ) ).toBeGT( 0 );
            });

            it( "maxDepth prunes nested nodes", function() {
                if ( !astSupported ) return;

                var result = tool.exec( { source: '<cfset x = 1>', maxDepth: 1 } );
                var ast = deserializeJSON( result.content[1].text );

                expect( ast.type ).toBe( "Program" );
                expect( ast.body[1].pruned ?: false ).toBeTrue();
            });

        });
    }
}
</cfscript>
