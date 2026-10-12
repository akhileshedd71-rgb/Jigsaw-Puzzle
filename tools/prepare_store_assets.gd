extends SceneTree
## Convert original artwork to Play Console's required pixel dimensions.
## Usage: godot --headless --path . --script tools/prepare_store_assets.gd -- /path/to/feature-source.png

func _initialize() -> void:
	var destination = "res://store_listing/graphics"
	DirAccess.make_dir_recursive_absolute(destination)
	var icon = Image.new()
	var error = icon.load_svg_from_string(FileAccess.get_file_as_string("res://assets/icon.svg"), 4.0)
	if error != OK or icon.get_size() != Vector2i(512, 512):
		push_error("Could not rasterize the original app icon at 512 × 512.")
		quit(1)
		return
	icon.save_png(destination.path_join("icon-512.png"))
	var arguments = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Supply the generated feature graphic source path.")
		quit(1)
		return
	var feature = Image.load_from_file(arguments[0])
	if feature == null or feature.is_empty():
		push_error("Could not read the feature graphic.")
		quit(1)
		return
	feature.resize(1024, 500, Image.INTERPOLATE_LANCZOS)
	feature.convert(Image.FORMAT_RGB8)
	if feature.save_png(destination.path_join("feature-1024x500.png")) != OK:
		quit(1)
		return
	print("Prepared 512 × 512 app icon and opaque 1024 × 500 feature graphic.")
	quit()
