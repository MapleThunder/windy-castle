# Headless test runner: godot --headless --path . -s tests/run_tests.gd [-- --filter=<substring>]
extends SceneTree


func _initialize() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var passed := 0
	var failed := 0
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var full := "%s:%s" % [file.get_basename(), name]
			if filter != "" and not filter in full:
				continue
			var inst: TestCase = script.new()
			inst.call(name)
			if inst.failures.is_empty():
				passed += 1
				print("PASS ", full)
			else:
				failed += 1
				print("FAIL ", full, ": ", "; ".join(inst.failures))
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)
