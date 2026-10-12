extends Control
## Piecepop: mobile-first, entirely offline, and intentionally interruption-free.

const UI = preload("res://scripts/ui_kit.gd")
const State = preload("res://scripts/game_state.gd")
const Board = preload("res://scripts/puzzle_board.gd")
const Confetti = preload("res://scripts/confetti.gd")
const BACKGROUNDS = [Color("eee8fb"), Color("dbf5f2"), Color("fff2d5"), Color("39364f")]

var state: PuzzleState
var frame: Control
var page: Control
var overlay: Control
var toast_layer: Control
var coin_labels: Array[Label] = []
var textures: Dictionary = {}
var thumbnails: Dictionary = {}
var current_tab = "gallery"
var category = "All"
var current_puzzle: Dictionary = {}
var grid_size = 6
var is_mystery = false
var board: PuzzleBoard
var progress_label: Label
var progress_bar: ProgressBar
var last_placed = 0
var edges_only = false
var reference_visible = false
var sound_player: AudioStreamPlayer
var resize_pending = false

func _ready() -> void:
	UI.initialize()
	if state == null:
		state = State.new()
	add_child(state)
	state.changed.connect(_refresh_coins)
	state.storage_error.connect(func(message): _toast(message))
	frame = Control.new()
	add_child(frame)
	frame.resized.connect(_on_frame_resized)
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -13
	sound_player.stream = _make_pop()
	add_child(sound_player)
	resized.connect(_layout_frame)
	_layout_frame()
	show_gallery()
	get_tree().auto_accept_quit = false
	if state.recovered_corrupt_save:
		_toast("A damaged save was backed up. Let's start fresh.")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),UI.PAPER)
	if size.x > 560:
		for i in range(14):
			var x = fmod(i * 143.0 + 30.0, size.x)
			var y = fmod(i * 227.0 + 80.0, size.y)
			draw_circle(Vector2(x,y), 18.0 + i%3 * 11.0, Color("eae4fa"))

func _layout_frame() -> void:
	frame.size = Vector2(minf(size.x, 540.0), size.y)
	frame.position = Vector2((size.x-frame.size.x)/2.0,0)
	queue_redraw()

func _on_frame_resized() -> void:
	if page == null or resize_pending:
		return
	resize_pending = true
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	resize_pending = false
	if is_instance_valid(board):
		board.position = Vector2(0, 158)
		board.size = Vector2(frame.size.x, maxf(390, frame.size.y - 258))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_board()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_board()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()

func _go_back() -> void:
	if is_instance_valid(overlay):
		_close_modal()
	elif is_instance_valid(board):
		_save_board()
		show_gallery()

func _new_page() -> void:
	_close_modal()
	if is_instance_valid(page):
		frame.remove_child(page)
		page.queue_free()
	board = null
	coin_labels.clear()
	page = Control.new()
	frame.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _texture(puzzle: Dictionary) -> Texture2D:
	if not textures.has(puzzle.id):
		# Keep full-resolution art for the current puzzle and recent previews.
		# A larger collection should not keep every original in mobile GPU memory.
		if textures.size() >= 3:
			textures.erase(textures.keys()[0])
		textures[puzzle.id] = load(puzzle.asset)
	return textures[puzzle.id]

func _thumbnail(puzzle: Dictionary) -> Texture2D:
	if not thumbnails.has(puzzle.id):
		var source = ResourceLoader.load(puzzle.asset, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		var picture = source.get_image()
		if picture.is_compressed():
			picture.decompress()
		picture.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		thumbnails[puzzle.id] = ImageTexture.create_from_image(picture)
	return thumbnails[puzzle.id]

func _header() -> void:
	var row = HBoxContainer.new()
	page.add_child(row)
	row.position = Vector2(22, 21)
	row.size = Vector2(frame.size.x-44,52)
	row.add_theme_constant_override("separation",10)
	var logo = UI.panel(UI.PURPLE,15)
	logo.custom_minimum_size = Vector2(43,43)
	row.add_child(logo)
	var glyph_margin = UI.margin(logo,10)
	glyph_margin.add_child(UI.icon("puzzle",UI.YELLOW,24))
	var name_label = UI.label("piecepop",29,UI.INK,900)
	row.add_child(name_label)
	UI.spacer(row)
	row.add_child(_coin_pill())
	var settings = UI.icon_button("settings",Color.WHITE,UI.MUTED,42)
	settings.tooltip_text = "Settings"
	settings.pressed.connect(_settings)
	row.add_child(settings)

func _coin_pill() -> Control:
	var pill = UI.panel(Color("fff3d2"),18)
	pill.custom_minimum_size.y = 40
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var margin = UI.margin(pill,8)
	var row = UI.hbox(margin,5)
	row.add_child(UI.icon("coin",UI.YELLOW,23))
	var amount = UI.label(str(state.coins),18,Color("946426"),900)
	row.add_child(amount)
	coin_labels.append(amount)
	return pill

func _refresh_coins() -> void:
	for label in coin_labels:
		if is_instance_valid(label):
			label.text = str(state.coins)

func _scroll_body(top: int = 89, bottom: int = 88) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = "PageScroll"
	page.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = top
	scroll.offset_bottom = -bottom
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var margin = UI.margin(scroll,22)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top",8)
	margin.add_theme_constant_override("margin_bottom",28)
	return UI.vbox(margin,20)

func _navigation(active: String) -> void:
	var bar = UI.panel(Color.WHITE,24,5)
	page.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -83
	bar.offset_bottom = 0
	var margin = UI.margin(bar,10)
	var row = UI.hbox(margin,8)
	for item in [["gallery","gallery","Explore"],["daily","calendar","Daily puzzle"],["saved","puzzle","My puzzles"]]:
		var selected = item[0] == active
		var button = UI.button("",Color("eee7ff") if selected else Color.WHITE,UI.PURPLE,62,17)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal",UI.box(Color("eee7ff") if selected else Color.WHITE,17))
		row.add_child(button)
		var stack = VBoxContainer.new()
		button.add_child(stack)
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_top = 7
		stack.add_theme_constant_override("separation",3)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glyph = UI.icon(item[1],UI.PURPLE if selected else UI.MUTED,24)
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(glyph)
		var title = UI.label(item[2],12,UI.PURPLE if selected else UI.MUTED,800)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(title)
		button.pressed.connect(func():
			match item[0]:
				"gallery": show_gallery()
				"daily": show_daily()
				"saved": show_saved()
		)

func show_gallery() -> void:
	current_tab = "gallery"
	_new_page()
	_header()
	var body = _scroll_body()
	var intro = UI.hbox(body,8)
	var text_stack = UI.vbox(intro,2)
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_child(UI.label("A little piece of happy.",30,UI.INK,900))
	text_stack.add_child(UI.label("%d puzzles. Five ways to play each one." % state.get_catalog().size(),15,UI.MUTED))
	var sparkle = UI.icon("sparkle",UI.PINK,32)
	sparkle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	intro.add_child(sparkle)
	_feature_card(body,state.puzzle_by_id("alpine_escape"))
	var filter_scroll = ScrollContainer.new()
	filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(filter_scroll)
	var filters = UI.hbox(filter_scroll,8)
	var categories: Array = ["All", "New"]
	for puzzle in state.get_catalog():
		if puzzle.get("is_new", false) and puzzle.category not in categories:
			categories.append(puzzle.category)
	for item in state.get_categories():
		if item not in categories: categories.append(item)
	var selected_filter: Control
	for cat in categories:
		var filter = UI.button(cat,UI.PURPLE if cat == category else Color.WHITE,Color.WHITE if cat == category else UI.MUTED,39,15)
		filter.add_theme_font_size_override("font_size",15)
		filter.custom_minimum_size.x = 86
		filter.pressed.connect(func(): category = cat; show_gallery())
		filters.add_child(filter)
		if cat == category: selected_filter = filter
	_scroll_to_filter.call_deferred(filter_scroll, selected_filter)
	var heading = UI.hbox(body)
	var library: Array = state.get_catalog()
	var visible_puzzles: Array = []
	for puzzle in library:
		if category == "New" and not puzzle.get("is_new", false):
			continue
		if category not in ["All", "New"] and puzzle.category != category:
			continue
		visible_puzzles.append(puzzle)
	# Surface the expansion first while keeping the original catalog IDs stable.
	var ordered_puzzles: Array = []
	for puzzle in visible_puzzles:
		if puzzle.get("is_new", false): ordered_puzzles.append(puzzle)
	for puzzle in visible_puzzles:
		if not puzzle.get("is_new", false): ordered_puzzles.append(puzzle)
	heading.add_child(UI.label("%d little escapes" % visible_puzzles.size(),21,UI.INK,900))
	UI.spacer(heading)
	heading.add_child(UI.label("OFFLINE READY",10,UI.MUTED,800))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",16)
	body.add_child(grid)
	for puzzle in ordered_puzzles:
		grid.add_child(_puzzle_card(puzzle))
	var note = UI.hbox(body,7)
	note.alignment = BoxContainer.ALIGNMENT_CENTER
	note.add_child(UI.icon("heart",UI.PINK,16))
	note.add_child(UI.label("No ads. No rush. Just one more piece.",13,UI.MUTED))
	_navigation("gallery")

func _scroll_to_filter(scroll: ScrollContainer, selected: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(selected):
		scroll.ensure_control_visible(selected)

func _feature_card(parent: Control, puzzle: Dictionary, daily: bool = false) -> void:
	var card = Control.new()
	card.custom_minimum_size.y = 278
	parent.add_child(card)
	var image = UI.image_rect(_texture(puzzle),24)
	card.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec2 q=abs(UV*vec2(440.0,278.0)-vec2(220.0,139.0))-vec2(196.0,115.0); float d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-24.0; COLOR=vec4(0.10,0.07,0.25,smoothstep(0.3,1.0,UV.y)*0.86*(1.0-smoothstep(-0.7,0.7,d))); }"
	var material = ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	var badge = UI.panel(Color.WHITE,12)
	card.add_child(badge)
	badge.position = Vector2(16,16)
	var bm = UI.margin(badge,8)
	var br = UI.hbox(bm,6)
	br.add_child(UI.icon("calendar" if daily else "sparkle",UI.PINK,15))
	br.add_child(UI.label("DAILY LITTLE ESCAPE" if daily else "THE HAPPY PLACE COLLECTION",10,UI.INK,900))
	var caption = VBoxContainer.new()
	card.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 20
	caption.offset_top = -88
	caption.offset_right = -80
	caption.add_theme_constant_override("separation",1)
	caption.add_child(UI.label(puzzle.title,28,Color.WHITE,900))
	caption.add_child(UI.label("A fresh perspective, piece by piece.",13,Color("ede5ff")))
	var play = UI.icon_button("arrow",UI.YELLOW,UI.INK,49)
	card.add_child(play)
	play.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	play.offset_left = -70
	play.offset_top = -73
	play.offset_right = -20
	play.offset_bottom = -23
	play.tooltip_text = "Play " + puzzle.title
	play.pressed.connect(func(): _choose_puzzle(puzzle))
	var hit = Button.new()
	card.add_child(hit)
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.offset_bottom = -82
	hit.flat = true
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.pressed.connect(func(): _choose_puzzle(puzzle))

func _puzzle_card(puzzle: Dictionary) -> Control:
	var card = UI.button("",Color.WHITE,UI.INK,216,21)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = (frame.size.x-58)/2.0
	card.tooltip_text = puzzle.title
	var artwork = UI.image_rect(_thumbnail(puzzle),17)
	card.add_child(artwork)
	artwork.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	artwork.offset_left = 7
	artwork.offset_right = -7
	artwork.offset_top = 7
	artwork.offset_bottom = 158
	var caption = UI.label(puzzle.title,17,UI.INK,900)
	card.add_child(caption)
	caption.position = Vector2(12,164)
	var small = UI.label(puzzle.category + "  ·  36–400 pieces",11,UI.MUTED)
	card.add_child(small)
	small.position = Vector2(12,188)
	if not state.is_unlocked(puzzle.id):
		var price = UI.panel(Color("fff3d2"),10)
		card.add_child(price)
		price.position = Vector2(14,15)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pm = UI.margin(price,5)
		pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pr = UI.hbox(pm,4)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.add_child(UI.icon("lock",Color("946426"),12))
		pr.add_child(UI.label(str(puzzle.price),11,Color("946426"),900))
	if puzzle.get("is_new", false):
		var badge = UI.panel(UI.PINK,9)
		card.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -61
		badge.offset_right = -14
		badge.offset_top = 15
		badge.offset_bottom = 39
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caption_margin = UI.margin(badge,5)
		caption_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var new_caption = UI.label("NEW",10,Color.WHITE,900)
		new_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption_margin.add_child(new_caption)
	card.pressed.connect(func(): _choose_puzzle(puzzle))
	return card

func show_daily() -> void:
	current_tab = "daily"
	_new_page()
	_header()
	var body = _scroll_body()
	var top = UI.vbox(body,4)
	top.add_child(UI.label("A fresh day. A fresh puzzle.",29,UI.INK,900))
	top.add_child(UI.label("Your daily moment of me-time.",16,UI.MUTED))
	var date = Time.get_datetime_dict_from_system()
	var months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
	body.add_child(UI.label("%s %d  ·  TODAY'S PICK" % [months[date.month-1],date.day],12,UI.PURPLE,900))
	_feature_card(body,state.daily_puzzle(),true)
	var play = UI.button("Make a little time for happy",UI.PURPLE)
	play.pressed.connect(func(): _choose_puzzle(state.daily_puzzle()))
	body.add_child(play)
	var info = UI.panel(Color("ede6ff"),22)
	body.add_child(info)
	var inner = UI.vbox(UI.margin(info,20),10)
	inner.add_child(UI.label("Your daily ritual, wherever you are.",20,UI.INK,900))
	var description = UI.label("A new pick from your offline collection each day. Choose your pace, take a breath, and enjoy the picture coming together.",16,UI.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(description)
	var ribbon = UI.hbox(inner,8)
	ribbon.add_child(UI.icon("download",UI.PURPLE,18))
	ribbon.add_child(UI.label("Always available. Even in airplane mode.",13,UI.PURPLE,800))
	_navigation("daily")

func show_saved() -> void:
	current_tab = "saved"
	_new_page()
	_header()
	var body = _scroll_body()
	body.add_child(UI.label("Your little masterpieces",29,UI.INK,900))
	body.add_child(UI.label("Pick up exactly where you left off.",16,UI.MUTED))
	var sessions = state.get_sessions()
	if sessions.is_empty():
		var empty = UI.panel(Color("ede6ff"),26)
		empty.custom_minimum_size.y = 280
		body.add_child(empty)
		var inner = UI.vbox(UI.margin(empty,28),20)
		var icon = UI.icon("puzzle",UI.PURPLE,70)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(icon)
		var title = UI.label("Every picture starts with a piece.",22,UI.INK,900)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(title)
		var pick = UI.button("Find your first puzzle",UI.PURPLE)
		pick.pressed.connect(show_gallery)
		inner.add_child(pick)
	for session in sessions:
		var puzzle = state.puzzle_by_id(session.id)
		var card = UI.panel(Color.WHITE,20,2)
		body.add_child(card)
		var row = UI.hbox(UI.margin(card,12),14)
		if session.mystery and not session.completed:
			var mystery_icon = UI.icon("puzzle",UI.PURPLE,70)
			row.add_child(mystery_icon)
		else:
			var image = UI.image_rect(_thumbnail(puzzle),12)
			image.custom_minimum_size = Vector2(88,88)
			row.add_child(image)
		var stack = UI.vbox(row,3)
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(UI.label(puzzle.title,19,UI.INK,900))
		stack.add_child(UI.label("%d pieces%s" % [session.grid*session.grid," · Mystery" if session.mystery else ""],13,UI.MUTED))
		stack.add_child(UI.label("Complete!" if session.completed else "%d%% placed" % int(float(session.progress)*100),13,UI.PURPLE,800))
		var resume = UI.icon_button("check" if session.completed else "arrow",UI.AQUA if session.completed else UI.PURPLE,Color.WHITE,42)
		resume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		resume.pressed.connect(func(): _start_puzzle(puzzle,session.grid,session.mystery,false))
		row.add_child(resume)
	_navigation("saved")

func _modal(height: float = 550) -> VBoxContainer:
	_close_modal()
	overlay = Control.new()
	frame.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim = ColorRect.new()
	dim.color = Color(0.13,0.08,0.25,0.48)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed: _close_modal())
	var panel = UI.panel(UI.PAPER,30,6)
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -minf(height,frame.size.y-30)
	panel.offset_bottom = 0
	var margin = UI.margin(panel,24)
	margin.add_theme_constant_override("margin_top",20)
	var stack = UI.vbox(margin,15)
	return stack

func _close_modal() -> void:
	if is_instance_valid(overlay):
		frame.remove_child(overlay)
		overlay.queue_free()
	overlay = null

func _modal_title(parent: Control, text: String) -> void:
	var row = UI.hbox(parent)
	row.add_child(UI.label(text,24,UI.INK,900))
	UI.spacer(row)
	var close = UI.icon_button("close",Color("eae4f4"),UI.MUTED,34)
	row.add_child(close)
	close.pressed.connect(_close_modal)

func _choose_puzzle(puzzle: Dictionary) -> void:
	if not state.is_unlocked(puzzle.id):
		_unlock_dialog(puzzle)
		return
	var stack = _modal(630)
	_modal_title(stack,"Your next happy place")
	var preview = Control.new()
	preview.custom_minimum_size.y = 161
	stack.add_child(preview)
	var image = UI.image_rect(_texture(puzzle),20)
	preview.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mystery_cover = UI.panel(UI.PURPLE,20)
	preview.add_child(mystery_cover)
	mystery_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mystery_cover.visible = false
	var cover_content = UI.vbox(UI.margin(mystery_cover,24),10)
	var cover_icon = UI.icon("puzzle",UI.YELLOW,52)
	cover_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cover_content.add_child(cover_icon)
	var cover_title = UI.label("A happy little surprise awaits.",20,Color.WHITE,900)
	cover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_content.add_child(cover_title)
	var title_row = UI.hbox(stack)
	var titles = UI.vbox(title_row,0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UI.label(puzzle.title,27,UI.INK,900))
	titles.add_child(UI.label(puzzle.tagline,14,UI.MUTED))
	var selected = {"grid":6,"mystery":false}
	var section = UI.hbox(stack)
	section.add_child(UI.label("How many little pieces?",17,UI.INK,800))
	UI.spacer(section)
	var reward_label = UI.label("+25 coins",13,Color("b77b21"),900)
	section.add_child(reward_label)
	var difficulties = UI.hbox(stack,8)
	var buttons: Array[Button] = []
	var play = UI.button("Let's play  ·  36 pieces",UI.PURPLE,Color.WHITE,56,18)
	for count in [6,10,12,16,20]:
		var difficulty = UI.button(str(count*count),UI.PURPLE if count==6 else Color.WHITE,Color.WHITE if count==6 else UI.INK,51,15)
		difficulty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		difficulty.add_theme_font_size_override("font_size",18)
		difficulties.add_child(difficulty)
		buttons.append(difficulty)
		difficulty.pressed.connect(func():
			selected.grid = count
			for b in buttons:
				var active = b == difficulty
				b.add_theme_stylebox_override("normal",UI.box(UI.PURPLE if active else Color.WHITE,15))
				b.add_theme_color_override("font_color",Color.WHITE if active else UI.INK)
			reward_label.text = "+%d coins" % state.reward_for_grid(count)
			_update_play_label(play,puzzle,selected))
	var mystery_panel = UI.panel(Color("eee8fc"),17)
	stack.add_child(mystery_panel)
	var mystery_row = UI.hbox(UI.margin(mystery_panel,12),10)
	mystery_row.add_child(UI.icon("sparkle",UI.PINK,24))
	var mystery_text = UI.vbox(mystery_row,0)
	mystery_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mystery_text.add_child(UI.label("Make it a mystery",16,UI.INK,900))
	mystery_text.add_child(UI.label("Hide the picture. Enjoy the surprise.",12,UI.MUTED))
	var toggle = CheckButton.new()
	toggle.tooltip_text = "Mystery mode: hide the reference picture"
	mystery_row.add_child(toggle)
	toggle.toggled.connect(func(enabled):
		selected.mystery = enabled
		image.modulate.a = 0.0 if enabled else 1.0
		mystery_cover.visible = enabled
		_update_play_label(play,puzzle,selected))
	stack.add_child(play)
	play.pressed.connect(func():
		var session = state.get_session(puzzle.id,selected.grid,selected.mystery)
		_start_puzzle(puzzle,selected.grid,selected.mystery,bool(session.get("completed",false))))
	_update_play_label(play,puzzle,selected)
	var note = UI.label("Saved as you go. Play at your own pace.",12,UI.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(note)

func _update_play_label(button: Button, puzzle: Dictionary, selection: Dictionary) -> void:
	var session = state.get_session(puzzle.id,selection.grid,selection.mystery)
	var word = "Let's play"
	if not session.is_empty():
		word = "Play again" if session.completed else "Continue"
	button.text = "%s  ·  %d pieces" % [word,selection.grid*selection.grid]

func _unlock_dialog(puzzle: Dictionary) -> void:
	var stack = _modal(470)
	_modal_title(stack,"A new little adventure")
	var image = UI.image_rect(_texture(puzzle),18)
	image.custom_minimum_size.y = 170
	stack.add_child(image)
	stack.add_child(UI.label(puzzle.title,27,UI.INK,900))
	var text = UI.label("Unlock this illustration forever with the coins you earn by finishing puzzles.",16,UI.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(text)
	var enough = state.coins >= int(puzzle.price)
	var unlock = UI.button("Unlock for %d coins" % puzzle.price if enough else "%d more coins to unlock" % (int(puzzle.price)-state.coins),UI.YELLOW,UI.INK,54)
	stack.add_child(unlock)
	unlock.pressed.connect(func():
		if state.unlock_puzzle(puzzle.id):
			_close_modal()
			show_gallery()
			_choose_puzzle(puzzle)
		else:
			_toast("Finish a puzzle to earn more coins. You've got this!"))

func _start_puzzle(puzzle: Dictionary, count: int, mystery: bool, restart: bool = false) -> void:
	current_puzzle = puzzle
	grid_size = count
	is_mystery = mystery
	edges_only = false
	reference_visible = false
	last_placed = 0
	var session = state.begin_session(puzzle.id,count,mystery,restart)
	if session.is_empty():
		_toast("This puzzle needs to be unlocked first.")
		return
	_new_page()
	var header = HBoxContainer.new()
	page.add_child(header)
	header.position = Vector2(20,22)
	header.size = Vector2(frame.size.x-40,52)
	header.add_theme_constant_override("separation",12)
	var back = UI.icon_button("back",Color.WHITE,UI.INK,44)
	back.tooltip_text = "Save and return to gallery"
	header.add_child(back)
	back.pressed.connect(func(): _save_board(); show_gallery())
	var titles = UI.vbox(header,0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UI.label(puzzle.title,22,UI.INK,900))
	titles.add_child(UI.label("%d pieces  ·  %s" % [count*count,"Mystery mode" if mystery else "A little moment for you"],12,UI.MUTED))
	header.add_child(_coin_pill())
	var progress_row = HBoxContainer.new()
	page.add_child(progress_row)
	progress_row.position = Vector2(25,91)
	progress_row.size = Vector2(frame.size.x-50,25)
	progress_label = UI.label("0 of %d pieces" % (count*count),14,UI.MUTED,800)
	progress_row.add_child(progress_label)
	UI.spacer(progress_row)
	var autosave = UI.hbox(progress_row,4)
	autosave.add_child(UI.icon("check",UI.AQUA,14))
	autosave.add_child(UI.label("Autosaved",12,UI.MUTED))
	progress_bar = ProgressBar.new()
	page.add_child(progress_bar)
	progress_bar.position = Vector2(25,124)
	progress_bar.size = Vector2(frame.size.x-50,8)
	progress_bar.show_percentage = false
	progress_bar.max_value = count*count
	progress_bar.add_theme_stylebox_override("background",UI.box(Color("e8e1f5"),4))
	progress_bar.add_theme_stylebox_override("fill",UI.box(UI.AQUA,4))
	progress_bar.size.y = 8
	board = Board.new()
	board.name = "PuzzleBoard"
	page.add_child(board)
	board.position = Vector2(0,158)
	board.size = Vector2(frame.size.x,maxf(390,frame.size.y-258))
	board.progress_changed.connect(_on_progress)
	board.state_changed.connect(_save_board)
	board.puzzle_completed.connect(_on_completed)
	board.interaction_message.connect(_toast)
	board.setup(_texture(puzzle),count,int(puzzle.id.hash()),session.get("state",{}),mystery)
	edges_only = board.edges_only
	board.set_board_color(BACKGROUNDS[state.background_index])
	_game_toolbar()
	if bool(session.get("completed",false)):
		_toast("Your masterpiece, all finished. Beautiful work!")
	elif session.get("state",{}).is_empty():
		_toast("Drag a piece from the tray onto the picture.")

func _game_toolbar() -> void:
	var toolbar = UI.panel(Color.WHITE,24,4)
	page.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toolbar.offset_top = -92
	var row = UI.hbox(UI.margin(toolbar,12),9)
	for item in [["hint","Hint"],["eye","Picture"],["edge","Edges"],["palette","Backdrop"],["plus","Zoom"]]:
		var button = UI.button("",Color.WHITE,UI.INK,66,16)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal",UI.box(Color("eee7ff") if item[0] == "edge" and edges_only else Color.WHITE,16))
		row.add_child(button)
		var stack = VBoxContainer.new()
		button.add_child(stack)
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_top = 8
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glyph = UI.icon(item[0],UI.PURPLE,25)
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(glyph)
		var title = UI.label(item[1],12,UI.INK,800)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(title)
		button.tooltip_text = item[1]
		button.pressed.connect(func():
			if not is_instance_valid(board): return
			match item[0]:
				"hint":
					if not board.use_hint(): _toast("Every piece is already home!")
				"eye":
					if is_mystery: _toast("The picture stays a surprise in mystery mode.")
					else:
						reference_visible = not reference_visible
						board.set_reference_visible(reference_visible)
						button.add_theme_stylebox_override("normal",UI.box(Color("eee7ff") if reference_visible else Color.WHITE,16))
				"edge":
					edges_only = not edges_only
					board.set_edges_only(edges_only)
					button.add_theme_stylebox_override("normal",UI.box(Color("eee7ff") if edges_only else Color.WHITE,16))
					_toast("Showing edge pieces" if edges_only else "Showing all pieces")
				"palette": _backdrop_dialog()
				"plus": _zoom_dialog()
		)

func _on_progress(placed: int, total: int) -> void:
	if is_instance_valid(progress_label): progress_label.text = "%d of %d pieces" % [placed,total]
	if is_instance_valid(progress_bar):
		progress_bar.create_tween().tween_property(progress_bar,"value",float(placed),0.25)
	if placed > last_placed:
		if state.sound_enabled: sound_player.play()
		if state.haptics_enabled and OS.has_feature("mobile"): Input.vibrate_handheld(22)
	last_placed = placed

func _save_board() -> void:
	if is_instance_valid(board) and not current_puzzle.is_empty():
		state.save_session(current_puzzle.id,grid_size,is_mystery,board.get_save_state())

func _on_completed() -> void:
	_save_board()
	var reward = state.complete_puzzle(current_puzzle.id,grid_size,is_mystery)
	call_deferred("_completion_dialog",reward)

func _completion_dialog(reward: int) -> void:
	var stack = _modal(610)
	var title = UI.label("You made a little magic!",28,UI.INK,900)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var sub = UI.label("One piece at a time. One beautiful escape.",14,UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(sub)
	var image = UI.image_rect(_texture(current_puzzle),22)
	image.custom_minimum_size.y = 275
	stack.add_child(image)
	var reward_row = UI.hbox(stack,8)
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_child(UI.icon("coin",UI.YELLOW,31))
	reward_row.add_child(UI.label("+%d happy little coins" % reward,22,Color("b77b21"),900))
	var next = UI.button("Find my next adventure",UI.PURPLE,Color.WHITE,54)
	stack.add_child(next)
	next.pressed.connect(show_gallery)
	var admire = UI.button("Stay and admire",Color("eee7ff"),UI.PURPLE,43)
	stack.add_child(admire)
	admire.pressed.connect(_close_modal)
	var confetti = Confetti.new()
	overlay.add_child(confetti)
	confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _backdrop_dialog() -> void:
	var stack = _modal(248)
	_modal_title(stack,"Set the mood")
	stack.add_child(UI.label("A comfy background for your puzzle.",15,UI.MUTED))
	var row = UI.hbox(stack,12)
	for index in range(BACKGROUNDS.size()):
		var swatch = UI.button("",BACKGROUNDS[index],UI.INK,70,18)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.tooltip_text = ["Lavender","Aqua","Sunshine","Midnight"][index]
		row.add_child(swatch)
		if state.background_index == index:
			var check = UI.icon("check",Color.WHITE if index==3 else UI.PURPLE,26)
			swatch.add_child(check)
			check.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			check.position -= Vector2(13,13)
			check.size = Vector2(26,26)
		swatch.pressed.connect(func():
			state.set_preferences({"background_index":index})
			board.set_board_color(BACKGROUNDS[index])
			_close_modal())

func _zoom_dialog() -> void:
	var stack = _modal(270)
	_modal_title(stack,"A closer look")
	var description = UI.label("Zoom in for tiny details. Pinch or scroll to zoom; drag empty board space to move around.",15,UI.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(description)
	var row = UI.hbox(stack,10)
	for item in [["− Zoom out",-0.5],["Reset",0.0],["Zoom in +",0.5]]:
		var button = UI.button(item[0],UI.PURPLE,Color.WHITE,50)
		button.add_theme_font_size_override("font_size",15)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		button.pressed.connect(func():
			if item[1] == 0.0: board.reset_view()
			else: board.change_zoom(item[1])
			_close_modal())

func _settings() -> void:
	var stack = _modal(412)
	_modal_title(stack,"Make yourself at home")
	for setting in [["sound_enabled","sound","Happy little sounds"],["haptics_enabled","heart","Gentle haptics"]]:
		var row = UI.hbox(stack,12)
		row.add_child(UI.icon(setting[1],UI.PURPLE,25))
		var label = UI.label(setting[2],17,UI.INK,800)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var toggle = CheckButton.new()
		toggle.button_pressed = state.get(setting[0])
		row.add_child(toggle)
		toggle.toggled.connect(func(value): state.set_preferences({setting[0]:value}))
	var info = UI.panel(Color("ede6ff"),18)
	stack.add_child(info)
	var inner = UI.vbox(UI.margin(info,16),5)
	inner.add_child(UI.label("A pocket-sized happy place.",20,UI.INK,900))
	var body = UI.label("%d original puzzles, always offline. Your progress is saved on this device. No ads, no accounts, no interruptions." % state.get_catalog().size(),15,UI.MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(body)
	stack.add_child(UI.label("PIECEPOP  /  MADE FOR LITTLE MOMENTS",11,UI.MUTED,800))

func _toast(message: String) -> void:
	if frame == null: return
	if is_instance_valid(toast_layer):
		frame.remove_child(toast_layer)
		toast_layer.queue_free()
	var panel = UI.panel(UI.INK,17,3)
	toast_layer = panel
	frame.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -158
	panel.offset_bottom = -108
	var margin = UI.margin(panel,12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label = UI.label(message,14,Color.WHITE,800)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(label)
	var tween = panel.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(panel,"modulate:a",0.0,0.35)
	tween.tween_callback(panel.queue_free)

func _make_pop() -> AudioStreamWAV:
	var sound = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples = PackedByteArray()
	for i in range(2425):
		var t = float(i)/22050.0
		var envelope = exp(-t*42.0) * minf(t*500,1.0)
		var value = int(sin(t*TAU*(750.0-t*1400.0))*envelope*15000)
		samples.append(value & 255)
		samples.append((value >> 8) & 255)
	sound.data = samples
	return sound
