<cfscript>
	if (!structKeyExists( application, "mcpServer" ) ) {
		application.mcpServer = new org.lucee.extension.mcp.MCPServer();
	}
	application.mcpServer.handle();
</cfscript>
