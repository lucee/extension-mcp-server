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
        variables.tool = new org.lucee.extension.mcp.tools.SearchLuceeDocs();
    }

    function afterAll() {
    }

    function run( testResults, testBox ) {

        describe( "checking the SearchLuceeDocs tool", function() {

            it( "checking name", function() {
                expect( tool.getName() ).toBe( "search_lucee_docs" );
            });

            it( "checking description", function() {
                expect( len( tool.getDescription() ) > 0 ).toBeTrue();
            });

            it( "checking inputSchema", function() {
                var schema = tool.getInputSchema();

                // required
                expect( isArray( schema.required ) ).toBeTrue();
                expect( arrayLen( schema.required ) ).toBe( 1 );
                expect( schema.required[1] ).toBe( "query" );

                // type
                expect( schema.type ).toBe( "object" );

                // properties
                expect( isStruct( schema.properties ) ).toBeTrue();
                expect( structKeyExists( schema.properties, "query" ) ).toBeTrue();
                expect( isStruct( schema.properties.query ) ).toBeTrue();
                expect( structKeyExists( schema.properties.query, "type" ) ).toBeTrue();
                expect( schema.properties.query.type ).toBe( "string" );
                expect( len( schema.properties.query.description ) > 0 ).toBeTrue();

                // optional maxResults property
                expect( structKeyExists( schema.properties, "maxResults" ) ).toBeTrue();
                expect( schema.properties.maxResults.type ).toBe( "integer" );
            });

            it( "checking exec returns correct content structure", function() {
                var result = tool.exec( { query: "arraySort" } );

                expect( isStruct( result ) ).toBeTrue();
                expect( structKeyExists( result, "content" ) ).toBeTrue();
                expect( isArray( result.content ) ).toBeTrue();
                expect( isStruct( result.content[1] ) ).toBeTrue();
                expect( structKeyExists( result.content[1], "type" ) ).toBeTrue();
                expect( result.content[1].type ).toBe( "text" );
                expect( len( result.content[1].text ) > 0 ).toBeTrue();
            });

            it( "search returns results for known term", function() {
                var result = tool.exec( { query: "arraySort" } );

                expect( findNoCase( "arraySort", result.content[1].text ) > 0 ).toBeTrue();
            });

            it( "maxResults limits number of results", function() {
                var result1 = tool.exec( { query: "array", maxResults: 1 } );
                var result3 = tool.exec( { query: "array", maxResults: 3 } );

                // both return content — we can't assert exact counts from the text
                // but we can assert the larger request returns more or equal text
                expect( len( result3.content[1].text ) >= len( result1.content[1].text ) ).toBeTrue();
            });

            it( "no results returns graceful not-found content", function() {
                var result = tool.exec( { query: "zzznoresultsxxx99999" } );

                expect( isStruct( result ) ).toBeTrue();
                expect( structKeyExists( result, "content" ) ).toBeTrue();
                expect( result.content[1].type ).toBe( "text" );
                expect( len( result.content[1].text ) > 0 ).toBeTrue();
            });

        });
    }
}
</cfscript>
