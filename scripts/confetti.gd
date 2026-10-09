extends Control

var particles: Array = []
var elapsed = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(80):
		particles.append({"position":Vector2(rng.randf_range(0,540),rng.randf_range(-500,-10)),"speed":rng.randf_range(80,210),"drift":rng.randf_range(-25,25),"spin":rng.randf_range(-2,2),"color":[Color("f756a1"),Color("25cbbd"),Color("ffce54"),Color("a886f5")][i%4]})

func _process(delta: float) -> void:
	elapsed += delta
	for p in particles:
		p.position += Vector2(p.drift,p.speed)*delta
	queue_redraw()
	if elapsed > 9.0: queue_free()

func _draw() -> void:
	for p in particles:
		draw_set_transform(p.position,elapsed*p.spin)
		draw_style_box(_confetti_box(p.color),Rect2(-3,-5,6,10))

func _confetti_box(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style
