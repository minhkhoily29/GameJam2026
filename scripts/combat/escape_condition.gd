extends node
var has_key: bool = false
func collected_escape_key() -> void:
has_key = true
func check_collected_key() = bool:
return has_key
