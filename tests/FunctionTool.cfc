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
        });
    }
}
</cfscript>

