extends TextureRect

const START_WIDTH = 10.0
const MIN_WIDTH = 0.1
const LEN_WIDTH_RATIO = 10.0
const EXTENSION_CHANCE = 0.5
const ANGLE_CHANGE = PI / 3

var width : int = rect_size.x
var height : int = rect_size.y
var river_mouth : Section

class Section:
	var width : float
	var source : Vector2
	var mouth : Section
	var tributaries : Array
	
	func _init(w : float, s : Vector2, m):
		width = w
		source = s
		mouth = m
		tributaries = []
		
	func get_angle() -> float:
		return mouth.source.angle_to(source)
	
	func draw(canvas : CanvasItem, color : Color):
		canvas.draw_line(mouth.source, source, color, width)
		for tributary in tributaries:
			tributary.draw(canvas, color)
	
	func make_tributaries():
		if width <= MIN_WIDTH:
			return
		# How many tributaries?
		if randf() < EXTENSION_CHANCE:
			# Get new angle, get new length, add 1 new tributary, move on
			_make_tributary(width - MIN_WIDTH, ANGLE_CHANGE)
		else:
			# Split width in 2
			var new_width = rand_range(MIN_WIDTH, width - MIN_WIDTH)
			_make_tributary(new_width, ANGLE_CHANGE * 2)
			_make_tributary(width - new_width, ANGLE_CHANGE * 2)
			
	func _make_tributary(new_width : float, angle_change : float):
			var new_angle : float = get_angle() + rand_range(-angle_change, angle_change)
			var direction : Vector2 = Vector2(new_width * LEN_WIDTH_RATIO, 0.0).rotated(new_angle) 
			var new_section : Section = Section.new(new_width, source + direction, self)
			tributaries.append(new_section)
			new_section.make_tributaries()
		

func _ready():
	var off_map := Section.new(START_WIDTH, Vector2(-1.0, height / 2), null)
	river_mouth = Section.new(START_WIDTH, Vector2(0.0, height / 2), off_map)
	
	seed(1)
	river_mouth.make_tributaries()

func _draw():
	# Take advantage of the inherited CanvasItem capability
	# This does not draw onto the image texture
	var white = Color(1.0, 1.0, 1.0, 1.0)
	river_mouth.draw(self, white)
