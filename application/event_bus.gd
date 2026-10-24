extends Node
## Sahne komutları → uygulama; uygulama olayları → sunum. Burada oyun kuralı yoktur.
signal command_requested(action: String, payload: Dictionary)
signal state_changed(snapshot: Dictionary)
signal feedback(message: String)

func request(action: String, payload: Dictionary = {}) -> void:
	command_requested.emit(action, payload)
