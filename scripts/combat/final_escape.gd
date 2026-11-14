extends Area2D
signal escape_successfull
sigal escape_denied
var door_opened : bool = false
func _ready() -> void:
    body_entered.connect(_on_body_entered)
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return
    if door_opened:
        return

    if EscapeCondition.check_collected_key():
        door_opened = true

        print("Escape successful!")
        escape_successful.emit()
    else:
        print("Door locked! Find the key in storage.")
        escape_denied.emit()
