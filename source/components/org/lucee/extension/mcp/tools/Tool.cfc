
abstract component   {

	variables.cache      = {};
	variables.cacheOrder = [];
	variables.cacheMax   = 512;
	variables.cacheHits  = 0;

	public  String function getName() {
		return variables.name;
	}
	public String function getDescription() {
		return variables.description;
	}
	public Struct function getInputSchema() {
		return variables.inputSchema;
	}

	/**
	 * In-memory LRU cache used by get_lucee_function and get_lucee_tag.
	 * Keyed by a normalised argument string; bounded by cacheMax (default 512).
	 */
	public numeric function getCacheSize() {
		return structCount( variables.cache );
	}
	public numeric function getCacheHitCount() {
		return variables.cacheHits;
	}
	public function setCacheMax( required numeric max ) {
		if ( arguments.max < 1 ) arguments.max = 1;
		variables.cacheMax = arguments.max;
	}

	private function getCached( required string key ) {
		lock name="lucee-mcp-tool-cache-#getName()#" type="exclusive" timeout="5" {
			if ( structKeyExists( variables.cache, arguments.key ) ) {
				arrayDelete( variables.cacheOrder, arguments.key );
				arrayAppend( variables.cacheOrder, arguments.key );
				variables.cacheHits++;
				return variables.cache[ arguments.key ];
			}
		}
		return;
	}

	private function putCached( required string key, required any value ) {
		lock name="lucee-mcp-tool-cache-#getName()#" type="exclusive" timeout="5" {
			if ( structKeyExists( variables.cache, arguments.key ) ) {
				arrayDelete( variables.cacheOrder, arguments.key );
			}
			else {
				while ( arrayLen( variables.cacheOrder ) >= variables.cacheMax ) {
					var evict = variables.cacheOrder[ 1 ];
					arrayDeleteAt( variables.cacheOrder, 1 );
					structDelete( variables.cache, evict );
				}
			}
			variables.cache[ arguments.key ] = arguments.value;
			arrayAppend( variables.cacheOrder, arguments.key );
		}
	}

	static function toTextContent( string text ) {
		return {
			"content": [
				{
					"type": "text",
					"text": arguments.text
				}
			]
		};
	}
}
