extends TextureRect

const POINT_SPACE : int = 20
const SPACE_PAD : int = 5

onready var width : int = rect_size.x
onready var height : int = rect_size.y
onready var max_dist : float = POINT_SPACE * 2.0

onready var point_grid : Array = []
onready var quad_grid : Array = []

class PointGridRef:
	var row : int
	var col : int
	var point_grid : Array
	
	func _init(r : int, c : int, grid : Array):
		row = r
		col = c
		point_grid = grid
	
	func point() -> Vector2:
		return point_grid[row][col]
	
	func distance_squared_to(b : PointGridRef) -> float:
		return point().distance_squared_to(b.point())

class GridTriangle:
	var a : PointGridRef
	var b : PointGridRef
	var c : PointGridRef
	var points : PoolVector2Array
	
	func _init(p1 : PointGridRef, p2 : PointGridRef, p3 : PointGridRef):
		a = p1
		b = p2
		c = p3
		points = PoolVector2Array([a.point(), b.point(), c.point(), a.point()])
	
	func draw(canvas : CanvasItem, color: Color):
		canvas.draw_polyline(points, color)

class GridQuad:
	var left : GridTriangle
	var right : GridTriangle
	var top : GridTriangle
	var bottom : GridTriangle
	
	func _init(start_ref : PointGridRef):
		# Depending on the length of diagonals, add 2 triangles to the graph
		# Assuming start_ref is top left and not on the right or bottom edge
		var tl := start_ref
		var tr := PointGridRef.new(start_ref.row, start_ref.col + 1, start_ref.point_grid)
		var bl := PointGridRef.new(start_ref.row + 1, start_ref.col, start_ref.point_grid)
		var br := PointGridRef.new(start_ref.row + 1, start_ref.col + 1, start_ref.point_grid)
		# Which way shall we split the quad?
		var tl_br_sqr = tl.distance_squared_to(br)
		var bl_tr_sqr = bl.distance_squared_to(tr)
		# Split along the shortest diagonal
		if tl_br_sqr > bl_tr_sqr:
			split_quad_bl_tr(tl, tr, bl, br)
		else:
			split_quad_tl_br(tl, tr, bl, br)
	
	func split_quad_bl_tr(tl : PointGridRef, tr : PointGridRef, bl : PointGridRef, br : PointGridRef):
		# Create 2 triangles for top/left and bottom/right
		left = GridTriangle.new(tl, tr, bl)
		right = GridTriangle.new(bl, tr, br)
		top = left
		bottom = right
	
	func split_quad_tl_br(tl : PointGridRef, tr : PointGridRef, bl : PointGridRef, br : PointGridRef):
		# Create 2 triangles for top/right and bottom/left
		left = GridTriangle.new(tl, br, bl)
		right = GridTriangle.new(tl, tr, br)
		top = right
		bottom = left
	

func _ready():
	
	# Create initial array of points
	for y in range(0, height - POINT_SPACE, POINT_SPACE):
		var point_row : Array = []
		for x in range(0, width - POINT_SPACE, POINT_SPACE):
			var new_point = Vector2(x + randi() % (POINT_SPACE - SPACE_PAD), y + randi() % (POINT_SPACE - SPACE_PAD))
			point_row.append(new_point)
		point_grid.append(point_row)

	# Create delaunay quad associations
	for row in range(0, point_grid.size() - 1):
		var quad_row : Array = []
		for col in range(0, point_grid[row].size() - 1):
			var quad = GridQuad.new(PointGridRef.new(row, col, point_grid))
			quad_row.append(quad)
		quad_grid.append(quad_row)

#	var image_texture := ImageTexture.new()
#	#Prepare image for drawing
#	var image : Image = Image.new()
#	image.create(width, height, false, Image.FORMAT_RGBA8)
#	image.lock()
#
#	var white = Color(1.0, 1.0, 1.0, 1.0)
#	# Show points:
#	for point_row in point_grid:
#		for point in point_row:
#			image.set_pixelv(point, white)
#
#	# Close and display image
#	image.unlock()
#	image_texture.create_from_image(image)
#	self.texture = image_texture

func _draw():
	# Take advantage of the inherited CanvasItem capability
	# This does not draw onto the image texture
	var white = Color(1.0, 1.0, 1.0, 1.0)
	# Show points:
	for quad_row in quad_grid:
		for quad in quad_row:
			var tri_top : GridTriangle = quad.top
			var tri_bottom : GridTriangle = quad.bottom
			tri_top.draw(self, white)
			tri_bottom.draw(self, white)
