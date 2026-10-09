class_name PopUI
extends RefCounted

const INK = Color("342456")
const MUTED = Color("8b82a0")
const PURPLE = Color("7950e8")
const PINK = Color("f756a1")
const AQUA = Color("25cbbd")
const YELLOW = Color("ffce54")
const PAPER = Color("f8f6ff")
const Icon = preload("res://scripts/pop_icon.gd")
static var regular: Font
static var bold: Font
static var heavy: Font

static func initialize() -> void:
	regular = load("res://assets/fonts/Nunito-Regular.ttf")
	bold = load("res://assets/fonts/Nunito-Bold.ttf")
	heavy = load("res://assets/fonts/Nunito-Black.ttf")

static func box(color: Color, radius: int = 18, border: Color = Color.TRANSPARENT, border_width: int = 0, shadow: int = 0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.shadow_color = Color("392157", 0.10)
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0, 4)
	return style

static func label(text: String, size: int = 20, color: Color = INK, weight: int = 600) -> Label:
	var item = Label.new()
	item.text = text
	item.add_theme_font_override("font", heavy if weight >= 900 else (bold if weight >= 800 else regular))
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

static func button(text: String, color: Color = PURPLE, foreground: Color = Color.WHITE, height: float = 50, radius: int = 18) -> Button:
	var item = Button.new()
	item.text = text
	item.custom_minimum_size.y = height
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_font_override("font", bold)
	item.add_theme_font_size_override("font_size", 18)
	item.add_theme_color_override("font_color", foreground)
	item.add_theme_color_override("font_hover_color", foreground)
	item.add_theme_color_override("font_pressed_color", foreground)
	item.add_theme_color_override("font_focus_color", foreground)
	item.add_theme_color_override("font_disabled_color", Color("aaa2ba"))
	var normal = box(color, radius, color.darkened(0.13), 0, 2)
	normal.border_width_bottom = 3
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	item.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = color.lightened(0.07)
	item.add_theme_stylebox_override("hover", hover)
	var pressed = normal.duplicate()
	pressed.bg_color = color.darkened(0.07)
	pressed.shadow_size = 0
	pressed.border_width_bottom = 0
	item.add_theme_stylebox_override("pressed", pressed)
	item.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, radius, AQUA, 2))
	item.add_theme_stylebox_override("disabled", box(Color("eeebf4"), radius))
	return item

static func icon(kind: String, color: Color = INK, size: float = 24) -> Control:
	var item = Icon.new()
	item.kind = kind
	item.tint = color
	item.custom_minimum_size = Vector2(size, size)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

static func icon_button(kind: String, color: Color = Color.WHITE, foreground: Color = INK, side: float = 46) -> Button:
	var item = button("", color, foreground, side, 16)
	item.custom_minimum_size.x = side
	var glyph = icon(kind, foreground, 24)
	item.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	glyph.position -= Vector2(12, 12)
	glyph.size = Vector2(24, 24)
	return item

static func panel(color: Color = Color.WHITE, radius: int = 22, shadow: int = 0) -> PanelContainer:
	var item = PanelContainer.new()
	item.add_theme_stylebox_override("panel", box(color, radius, Color.TRANSPARENT, 0, shadow))
	return item

static func margin(parent: Node, amount: int = 20) -> MarginContainer:
	var item = MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		item.add_theme_constant_override("margin_" + edge, amount)
	parent.add_child(item)
	return item

static func vbox(parent: Node, separation: int = 12) -> VBoxContainer:
	var item = VBoxContainer.new()
	item.add_theme_constant_override("separation", separation)
	parent.add_child(item)
	return item

static func hbox(parent: Node, separation: int = 10) -> HBoxContainer:
	var item = HBoxContainer.new()
	item.add_theme_constant_override("separation", separation)
	parent.add_child(item)
	return item

static func spacer(parent: Node) -> Control:
	var item = Control.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(item)
	return item

static func image_rect(texture: Texture2D, radius: float = 18) -> TextureRect:
	var item = TextureRect.new()
	item.texture = texture
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; uniform float radius = 18.0; uniform vec2 rect_size = vec2(200.0); varying vec2 local_pos; void vertex(){local_pos=VERTEX;} void fragment(){ vec4 c=texture(TEXTURE,UV); vec2 q=abs(local_pos-rect_size*0.5)-(rect_size*0.5-vec2(radius)); float d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-radius; COLOR=c*vec4(1.0,1.0,1.0,1.0-smoothstep(-0.7,0.7,d)); }"
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("radius", radius)
	item.material = material
	item.resized.connect(func(): material.set_shader_parameter("rect_size", item.size))
	return item
