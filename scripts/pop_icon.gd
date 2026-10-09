extends Control

var kind = "sparkle"
var tint = Color("342456")

func _draw() -> void:
	var s = size / 24.0
	draw_set_transform(Vector2.ZERO, 0, s)
	var w = 2.0
	match kind:
		"back":
			draw_polyline(PackedVector2Array([Vector2(14,5),Vector2(7,12),Vector2(14,19)]),tint,2.5,true)
		"close":
			draw_line(Vector2(6,6),Vector2(18,18),tint,w,true)
			draw_line(Vector2(18,6),Vector2(6,18),tint,w,true)
		"arrow":
			draw_line(Vector2(4,12),Vector2(20,12),tint,w,true)
			draw_polyline(PackedVector2Array([Vector2(14,6),Vector2(20,12),Vector2(14,18)]),tint,w,true)
		"coin":
			draw_circle(Vector2(12,12),10,Color("f4a92e"))
			draw_circle(Vector2(12,10.5),9,Color("ffdb64"))
			draw_arc(Vector2(12,10.5),6,0,TAU,24,Color("f5b738"),1.8,true)
			draw_line(Vector2(12,7),Vector2(12,14),Color("c28118"),2.3,true)
		"gallery":
			for y in [3,13]:
				for x in [3,13]:
					draw_style_box(_square(tint),Rect2(x,y,8,8))
		"calendar":
			draw_style_box(_square(tint),Rect2(3,5,18,16))
			draw_line(Vector2(4,10),Vector2(20,10),Color.WHITE,1.5,true)
			draw_line(Vector2(8,2),Vector2(8,7),tint,2.5,true)
			draw_line(Vector2(16,2),Vector2(16,7),tint,2.5,true)
			draw_circle(Vector2(8,15),1.4,Color.WHITE)
			draw_circle(Vector2(15,15),1.4,Color.WHITE)
		"puzzle":
			var pts = PackedVector2Array([Vector2(3,4),Vector2(10,4),Vector2(10,2),Vector2(11,0.5),Vector2(14,0.5),Vector2(15,2),Vector2(15,4),Vector2(21,4),Vector2(21,10),Vector2(23,10),Vector2(24,12),Vector2(23,14),Vector2(21,14),Vector2(21,21),Vector2(14,21),Vector2(14,19),Vector2(12,18),Vector2(10,19),Vector2(10,21),Vector2(3,21),Vector2(3,14),Vector2(5,14),Vector2(6,12),Vector2(5,10),Vector2(3,10)])
			draw_colored_polygon(pts,tint)
		"heart":
			draw_circle(Vector2(8,9),5,tint)
			draw_circle(Vector2(16,9),5,tint)
			draw_colored_polygon(PackedVector2Array([Vector2(3.3,10),Vector2(20.7,10),Vector2(12,21)]),tint)
		"sparkle":
			draw_colored_polygon(PackedVector2Array([Vector2(12,1),Vector2(15,9),Vector2(23,12),Vector2(15,15),Vector2(12,23),Vector2(9,15),Vector2(1,12),Vector2(9,9)]),tint)
		"hint":
			draw_arc(Vector2(12,9),6,0,TAU,28,tint,w,true)
			draw_polyline(PackedVector2Array([Vector2(8,14),Vector2(9,18),Vector2(15,18),Vector2(16,14)]),tint,w,true)
			draw_line(Vector2(10,21),Vector2(14,21),tint,2.5,true)
		"eye":
			draw_polyline(PackedVector2Array([Vector2(1,12),Vector2(5,7),Vector2(12,5),Vector2(19,7),Vector2(23,12),Vector2(19,17),Vector2(12,19),Vector2(5,17),Vector2(1,12)]),tint,w,true)
			draw_circle(Vector2(12,12),3.5,tint)
		"edge":
			draw_rect(Rect2(4,4,16,16),tint,false,w)
			draw_line(Vector2(4,4),Vector2(20,4),tint,4,true)
			draw_line(Vector2(4,4),Vector2(4,20),tint,4,true)
		"palette":
			draw_circle(Vector2(12,12),10,tint)
			for p in [Vector2(8,7),Vector2(15,6),Vector2(18,12),Vector2(7,14)]:
				draw_circle(p,2.1,Color.WHITE)
		"lock":
			draw_arc(Vector2(12,9),5,PI,TAU,20,tint,2.5,true)
			draw_style_box(_square(tint),Rect2(4,9,16,12))
			draw_line(Vector2(12,13),Vector2(12,17),Color.WHITE,2,true)
		"check":
			draw_polyline(PackedVector2Array([Vector2(4,12),Vector2(10,18),Vector2(21,6)]),tint,3,true)
		"plus":
			draw_line(Vector2(5,12),Vector2(19,12),tint,2.4,true)
			draw_line(Vector2(12,5),Vector2(12,19),tint,2.4,true)
		"minus":
			draw_line(Vector2(5,12),Vector2(19,12),tint,2.4,true)
		"sound":
			draw_colored_polygon(PackedVector2Array([Vector2(3,9),Vector2(7,9),Vector2(13,4),Vector2(13,20),Vector2(7,15),Vector2(3,15)]),tint)
			draw_arc(Vector2(12,12),7,-0.85,0.85,18,tint,w,true)
			draw_arc(Vector2(12,12),11,-0.85,0.85,18,tint,w,true)
		"settings":
			for i in range(8):
				var direction = Vector2.from_angle(i*TAU/8)
				draw_line(Vector2(12,12)+direction*7,Vector2(12,12)+direction*10,tint,4,true)
			draw_arc(Vector2(12,12),6,0,TAU,28,tint,3,true)
		"download":
			draw_line(Vector2(12,3),Vector2(12,15),tint,w,true)
			draw_polyline(PackedVector2Array([Vector2(7,10),Vector2(12,15),Vector2(17,10)]),tint,w,true)
			draw_polyline(PackedVector2Array([Vector2(4,16),Vector2(4,21),Vector2(20,21),Vector2(20,16)]),tint,w,true)

func _square(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style
