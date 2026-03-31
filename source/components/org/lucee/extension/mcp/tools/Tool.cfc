
abstract component   {

	public  String function getName() {
		return variables.name;
	}
	public String function getDescription() {
		return variables.description;
	}
	public Struct function getInputSchema() {
		return variables.inputSchema;
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
