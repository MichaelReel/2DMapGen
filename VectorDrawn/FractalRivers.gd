extends TextureRect

const START_WIDTH = 30.0
const START_ANGLE = 0.0
const MIN_WIDTH = 0.1
const LEN_WIDTH_RATIO = 10.0
const EXTENSION_CHANCE = 0.5
const START_ANGLE_CHANGE = PI / 6

var width : int = rect_size.x
var height : int = rect_size.y
var river_mouth : Section

class Section:
	var width : float
	var angle : float
	var source : Vector2
	var mouth : Section
	var tributaries : Array
	
	func _init(w : float, a : float, s : Vector2, m):
		width = w
		angle = a
		source = s
		mouth = m
		tributaries = []
	
	func draw(canvas : CanvasItem, color : Color):
		if mouth != null:
			canvas.draw_line(mouth.source, source, color, width)
		for tributary in tributaries:
			tributary.draw(canvas, color)
	
	func make_tributaries(angle_change):
		if width <= MIN_WIDTH:
			return

		# Split width in 2
		var new_width = rand_range(MIN_WIDTH, width - MIN_WIDTH)
		_make_tributary(new_width, -angle_change)
		_make_tributary(width - new_width, angle_change)
			
	func _make_tributary(new_width : float, angle_change : float):
			var new_angle : float = angle + angle_change
			# Bigger the angle change, shorter the section
			var section_len = new_width * LEN_WIDTH_RATIO
			var direction : Vector2 = Vector2(section_len, 0.0).rotated(new_angle) 
			var new_section : Section = Section.new(new_width, new_angle, source + direction, self)
			tributaries.append(new_section)
			new_section.make_tributaries(angle_change / 2.0)
		

func _ready():
	river_mouth = Section.new(START_WIDTH, START_ANGLE, Vector2(0.0, height / 2), null)
	
	seed(1)
	river_mouth.make_tributaries(START_ANGLE_CHANGE)

func _draw():
	# Take advantage of the inherited CanvasItem capability
	# This does not draw onto the image texture
	var white = Color(1.0, 1.0, 1.0, 1.0)
	river_mouth.draw(self, white)
