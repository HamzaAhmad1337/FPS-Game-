extends SceneTree
## Headless logic test runner.
##   .tools/godot --headless --path . --script res://tools/test/test_runner.gd
## Exits 0 when every case passes, 1 otherwise.

const CASES_DIR := "res://tools/test/cases"


func _initialize() -> void:
	var files := _case_files()
	if files.is_empty():
		print("no test cases found in %s" % CASES_DIR)
		quit(1)
		return

	var total := 0
	var failures: Array[String] = []

	for path in files:
		var script: GDScript = load(path)
		var instance: TestCase = script.new()
		var case_name := path.get_file().get_basename()
		for method in instance.get_method_list():
			var mname: String = method["name"]
			if not mname.begins_with("test_"):
				continue
			total += 1
			instance.failures.clear()
			instance.set_current("%s.%s" % [case_name, mname])
			instance.before_each()
			instance.call(mname)
			instance.after_each()
			for f in instance.failures:
				failures.append(f)

	print("\n--- tests: %d run, %d failed ---" % [total, failures.size()])
	for f in failures:
		print("  FAIL %s" % f)
	quit(1 if failures.size() > 0 else 0)


func _case_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(CASES_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".gd"):
			out.append("%s/%s" % [CASES_DIR, name])
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
