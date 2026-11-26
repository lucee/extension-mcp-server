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
        variables.tool=new org.lucee.extension.mcp.tools.Functions()  
    }

    function afterAll() {
    }

    function run(testResults, testBox) {


        // -------------------------------------------------------------------------
        describe("checking the Functions tool", function() {

            it("checking name", function() {
                expect(	tool.getName() ).toBe( "get_lucee_function" );
            }); 
            it("checking description", function() {
                expect(	len(tool.getDescription())>0 ).toBeTrue(  );
            }); 
            it("checking inputSchema", function() {
                var schema=tool.getInputSchema();
                
                // required
                expect( isArray(schema.required) ).toBeTrue(  );
                expect( ArrayLen(schema.required) ).toBe( 1 );
                expect( schema.required[1] ).toBe( "name" );
                
                // type
                expect( schema.type ).toBe( "object" );

                // properties
                expect( isStruct(schema.properties) ).toBeTrue(  );
                expect( structKeyExists(schema.properties,"name") ).toBeTrue(  );
                expect( isStruct(schema.properties.name) ).toBeTrue(  );
                expect( structKeyExists(schema.properties.name,"type") ).toBeTrue(  );
                expect( schema.properties.name.type ).toBe( "string" );
                expect( len(schema.properties.name.description)>0 ).toBeTrue();
            }); 
            it("checking exec", function() {
                var result=tool.exec({name:"arrayLen"});
                
                expect( isStruct(result) ).toBeTrue(  );
                expect( structKeyExists(result,"content") ).toBeTrue(  );
                expect( isArray(result.content) ).toBeTrue(  );
                expect( isStruct(result.content[1]) ).toBeTrue(  );
                expect( structKeyExists(result.content[1],"type") ).toBeTrue(  );
                expect( result.content[1].type ).toBe( "text" );
                
            });

            it("caches results by normalised name", function() {
                var t = new org.lucee.extension.mcp.tools.Functions();
                expect( t.getCacheSize() ).toBe( 0 );
                expect( t.getCacheHitCount() ).toBe( 0 );
                var first = t.exec({ name: "arraySort" });
                expect( t.getCacheSize() ).toBe( 1 );
                expect( t.getCacheHitCount() ).toBe( 0 );
                var second = t.exec({ name: "  ARRAYSORT " });
                expect( t.getCacheSize() ).toBe( 1 );
                expect( t.getCacheHitCount() ).toBe( 1 );
                expect( second.content[1].text ).toBe( first.content[1].text );
            });

            it("evicts the least recently used entry when the cache is full", function() {
                var t = new org.lucee.extension.mcp.tools.Functions();
                t.setCacheMax( 2 );
                t.exec({ name: "arraySort" });
                t.exec({ name: "arrayLen" });
                t.exec({ name: "arraySort" }); // hit, arraySort is MRU, arrayLen is LRU
                t.exec({ name: "listToArray" }); // evicts arrayLen
                expect( t.getCacheSize() ).toBe( 2 );
                var hits = t.getCacheHitCount();
                t.exec({ name: "arraySort" });
                expect( t.getCacheHitCount() ).toBe( hits + 1 );
                t.exec({ name: "arrayLen" });
                expect( t.getCacheHitCount() ).toBe( hits + 1 );
            });
        });
    }
}
</cfscript>

