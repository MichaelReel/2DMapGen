extends TextureRect

onready var width : int = rect_size.x
onready var height : int = rect_size.y
onready var max_sqr_dist : float = width * height
onready var max_dist : float = sqrt(max_sqr_dist)

class Point:
	var pos : Vector2
	var nearest : Array = []
	
	func _init(p : Vector2):
		pos = p
	
	func sort_nearest(a : Point, b : Point) -> bool:
		return (a.pos.distance_squared_to(pos) < b.pos.distance_squared_to(pos))
	
	func set_nearest(neighbours : Array):
		nearest = [] + neighbours
	
	func distance_to_nearest(max_dist : float) -> float:
		nearest.sort_custom(self, "sort_nearest")
		var n0 = nearest[0].pos
		var proximity = n0.distance_to(pos) / max_dist
		return proximity

func _ready():
	var image_texture := ImageTexture.new()
	var point_count : int = 50

	# Create initial array of points
	var points : Array = []
	for _p in range(0, point_count):
		points.append(Point.new(Vector2(randi() % width, randi() % height)))

	#Prepare image for drawing
	var image : Image = Image.new()
	image.create(width, height, false, Image.FORMAT_RGBA8)
	image.lock()

	var fragment = Point.new(Vector2())
	fragment.set_nearest(points)
	
	for y in range(0, height, 1):
		fragment.pos.y = y
		for x in range(0, width, 1):
			fragment.pos.x = x
			# Draw color based on the nearest point
			var col : Color = Color(0.0, 0.0, 0.0, 1.0)
			col.r = fragment.distance_to_nearest(max_dist)
			col.b = col.r
			col.g = col.r
			
			image.set_pixelv(fragment.pos, col)
	
	var white = Color(1.0, 1.0, 1.0, 1.0)
	for point in points:
		image.set_pixelv(point.pos, white)
	
	# Close and display image
	image.unlock()
	image_texture.create_from_image(image)
	self.texture = image_texture
