extends TextureRect

const POINT_SPACE : int = 30

onready var width : int = rect_size.x
onready var height : int = rect_size.y
onready var max_dist : float = POINT_SPACE * 2.0

onready var point_grid : Array = []
onready var image : Image = Image.new()
onready var fragment = Point.new(Vector2())
onready var noise : OpenSimplexNoise = OpenSimplexNoise.new()

class Point:
	const COLOR_MAP : Dictionary = {
		-0.7 : Color(0.2, 0.2, 0.5, 1.0),
		-0.5 : Color(0.4, 0.4, 0.7, 1.0),
		-0.45 : Color(1.0, 1.0, 0.6, 1.0),
		0.0 : Color(0.6, 1.0, 0.6, 1.0),
		0.5 : Color(0.7, 1.0, 0.7, 1.0),
		0.7 : Color.brown,
		0.75 : Color(0.7, 0.7, 0.7, 1.0),
		1.0 : Color(1.0, 1.0, 1.0, 1.0),
	}

	var pos : Vector2
	var neighbours : Array = []
	var color : Color = Color()
	
	func _init(p : Vector2, noise : OpenSimplexNoise = null):
		pos = p
		if noise:
			var noise_2d = noise.get_noise_2dv(pos)
			for key in COLOR_MAP.keys():
				if key > noise_2d:
					color = COLOR_MAP[key]
					break
	
	func sort_nearest(a : Point, b : Point) -> bool:
		return (a.pos.distance_squared_to(pos) < b.pos.distance_squared_to(pos))

	func set_neighbours(locals : Array):
		neighbours = [] + locals
	
	func associate_neighbours():
		for n in neighbours:
			n.add_neighbour(self)

	func add_neighbour(p : Point):
		neighbours.append(p)

	func sort_neighbours():
		neighbours.sort_custom(self, "sort_nearest")

	func distance_to_nearest() -> float:
		return neighbours[0].pos.distance_to(pos)
	
	func color_of_nearest() -> Color:
		return neighbours[0].color

func passthrough_neighbourhood(p : Point):
	var col : int = p.pos.x / POINT_SPACE
	var row : int = p.pos.y / POINT_SPACE
	var estate : Point = point_grid[row][col]
	p.set_neighbours([estate] + estate.neighbours)

func _ready():
	noise.octaves = 1
	noise.persistence = 0.75
	noise.period = 300
	
	# Create initial array of points
	var row = 0
	for y in range(0, height, POINT_SPACE):
		var point_row : Array = []
		var col = 0
		for x in range(0, width, POINT_SPACE):
			var new_point = Point.new(Vector2(x + randi() % POINT_SPACE, y + randi() % POINT_SPACE), noise)
			var neighbours = []
			# Connect to existing neighbours and they should connect back
			if row > 0:
				var last_row : Array = point_grid[row - 1]
				if col > 0:
					neighbours.append(last_row[col - 1])
				neighbours.append(last_row[col])
				if col < (width / POINT_SPACE):
					neighbours.append(last_row[col + 1])
			if col > 0:
				neighbours.append(point_row[col - 1])
			new_point.set_neighbours(neighbours)
			new_point.associate_neighbours()
			point_row.append(new_point)
			col += 1
		point_grid.append(point_row)
		row += 1
			
	#Prepare image for drawing
	image.create(width, height, false, Image.FORMAT_RGBA8)

func _process(delta):
	# Draw image line by line
	image.lock()

	if fragment.pos.y < height:
		for x in range(0, width, 1):
			fragment.pos.x = x
			
			# get the local neighbourhood
			passthrough_neighbourhood(fragment)
			
			# Draw color based on the nearest point
			fragment.sort_neighbours()
			image.set_pixelv(fragment.pos, fragment.color_of_nearest())
		fragment.pos.y += 1
	else:
		set_process(false)

	# Close and display image
	image.unlock()
	var image_texture := ImageTexture.new()
	image_texture.create_from_image(image)
	self.texture = image_texture

#func _draw():
#	# Debug stuff really
#	var light_grey = Color(0.8, 0.8, 0.8, 1.0)
#	var white = Color(1.0, 1.0, 1.0, 1.0)
#
#	# Show connections:
#	for point_row in point_grid:
#		for point in point_row:
#			for neighbour in point.neighbours:
#				draw_line(point.pos, neighbour.pos, light_grey)
#
#	# Show points:
#	for point_row in point_grid:
#		for point in point_row:
#			draw_circle(point.pos, 2.0, white)
	
