extends SceneTree


func _init() -> void:
	const extension_path := "res://addons/airwindohhs_godot/airwindohhs_godot.gdextension"
	if not ClassDB.class_exists("AirwindohhsAmbienceADT"):
		var load_status := GDExtensionManager.load_extension(extension_path)
		assert(
			load_status == GDExtensionManager.LOAD_STATUS_OK
			or load_status == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED,
			"failed to load built extension: " + str(load_status)
		)

	var catalog_file := FileAccess.open("res://addons/airwindohhs_godot/catalog.json", FileAccess.READ)
	assert(catalog_file != null, "generated catalog is missing")
	var catalog: Dictionary = JSON.parse_string(catalog_file.get_as_text())
	assert(catalog.compatible_effect_count == 495)
	for effect: Dictionary in catalog.effects:
		assert(ClassDB.class_exists(effect.godot_class), "missing class: " + effect.godot_class)

	var effect: Object = ClassDB.instantiate("AirwindohhsDynamicsButterComp")
	assert(effect != null)
	assert(effect.get_effect_id() == "dynamics.buttercomp")
	assert(effect.get_parameter_ids().size() == 2)
	effect.set("parameters/compress", 0.75)
	assert(is_equal_approx(effect.get("parameters/compress"), 0.75))

	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "AirwindohhsSmokeTest")
	AudioServer.add_bus_effect(bus, effect)
	assert(AudioServer.get_bus_effect_count(bus) == 1)
	AudioServer.remove_bus(bus)
	print("AIRWINDOHHHS_GODOT_SMOKE_OK effects=", catalog.compatible_effect_count)
	quit(0)
