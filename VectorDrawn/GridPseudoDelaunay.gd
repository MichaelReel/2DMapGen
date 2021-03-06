extends TextureRect

const POINT_SPACE : int = 50
const SPACE_PAD : int = POINT_SPACE / 2

onready var width : int = rect_size.x
onready var height : int = rect_size.y
onready var max_dist : float = POINT_SPACE * 2.0

onready var point_grid : Array = []
onready var quad_grid : Array = []
onready var voronoi_edges : Array = []

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
	var circ_cent : Vector2
	
	func _init(p1 : PointGridRef, p2 : PointGridRef, p3 : PointGridRef):
		a = p1
		b = p2
		c = p3
		points = PoolVector2Array([a.point(), b.point(), c.point(), a.point()])
		circ_cent = calculate_circumcenter(a.point(), b.point(), c.point())
	
	func draw(canvas : CanvasItem, color: Color):
		canvas.draw_polyline(points, color)
		canvas.draw_circle(circ_cent, 1.0, color)
		for p in points:
			canvas.draw_circle(p, 2.0, color)
	
	static func calculate_circumcenter(vA : Vector2, vB : Vector2, vC : Vector2) -> Vector2:
		var result : Vector2 = Vector2()
		var temp = (vB.y * vC.x) - (vB.y * vA.x) - (vA.y * vC.x) - (vC.y * vB.x) + (vC.y * vA.x) + (vA.y * vB.x)
		if temp == 0:
			print("The three points entered are collinear (on the same line), so they don't form a triangle. Circumcenter can't be calculated.")
		else :
			var dia = 2 * (vA.x * (vB.y - vC.y) + vB.x * (vC.y - vA.y) + vC.x * (vA.y - vB.y))
			var firstsq = ((vA.x * vA.x) + (vA.y * vA.y))
			var secondsq = ((vB.x * vB.x) + (vB.y * vB.y))
			var thirdsq = ((vC.x * vC.x) + (vC.y * vC.y))
			result.x = (firstsq * (vB.y - vC.y) + secondsq * (vC.y - vA.y) + thirdsq * (vA.y - vB.y)) / dia
			result.y = (firstsq * (vC.x - vB.x) + secondsq * (vA.x - vC.x) + thirdsq * (vB.x - vA.x)) / dia
		
		return result

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
	
	# Changes to the functions above will require changes to the functions below
	func top_left() -> Vector2:
		return left.a.point()
	
	func top_right() -> Vector2:
		return right.b.point()
	
	func bottom_left() -> Vector2:
		return left.c.point()
	
	func bottom_right() -> Vector2:
		return right.c.point()
	

class VoronoiEdge:
	var v1 : Vector2
	var v2 : Vector2
	
	func _init(a : Vector2, b : Vector2):
		v1 = a
		v2 = b
	
	func draw(canvas : CanvasItem, color: Color):
		canvas.draw_line(v1, v2, color)

func _ready():
	# Really this sets up a kind of pseudo-delaunay graph
	# Really just a grid of variable-sized triangles
	# This simiplies lots of stuff, avoids using fortunes
	# and generally takes almost no time at all
	
	# Create initial array of points
	for y in range(0, height - POINT_SPACE, POINT_SPACE):
		var point_row : Array = []
		for x in range(0, width - POINT_SPACE, POINT_SPACE):
			# Don't stray further than POINT_SPACE - SPACE_PAD from the anchor
			var distance = randi() % (POINT_SPACE - SPACE_PAD)
			var angle = randf() * (PI / 2)
			var new_x = x + cos(angle) * distance
			var new_y = y + sin(angle) * distance
			var new_point = Vector2(new_x, new_y)
			point_row.append(new_point)
		point_grid.append(point_row)

	# Create delaunay quad associations
	for row in range(0, point_grid.size() - 1):
		var quad_row : Array = []
		for col in range(0, point_grid[row].size() - 1):
			var quad = GridQuad.new(PointGridRef.new(row, col, point_grid))
			quad_row.append(quad)
		quad_grid.append(quad_row)
	
	# Create voronoi connections
	for row in range(0, quad_grid.size()):
		for col in range(0, quad_grid[row].size()):
			var quad = quad_grid[row][col]
			# The 2 tris in the quad will be connected anyway
			voronoi_edges.append(VoronoiEdge.new(quad.left.circ_cent, quad.right.circ_cent))
			# If we're on an edge we should have an edge connector
			# Get the normal on the box edge and make out line to edge
			# If not edge then just connect to the triangle on that side
			var new_vector : Vector2
			if row == 0:
				var normal : Vector2 = quad.top_right().direction_to(quad.top_left()).tangent()
				var edge_x : float = quad.top.circ_cent.x - (normal.x * (quad.top.circ_cent.y / normal.y))
				new_vector = Vector2(edge_x, 0.0)
			else:
				new_vector = quad_grid[row - 1][col].bottom.circ_cent
			voronoi_edges.append(VoronoiEdge.new(new_vector, quad.top.circ_cent))
			
			if col == 0:
				var normal : Vector2 = quad.top_left().direction_to(quad.bottom_left()).tangent()
				var edge_y : float = quad.left.circ_cent.y - (normal.y * (quad.left.circ_cent.x / normal.x))
				new_vector = Vector2(0.0, edge_y)
			else:
				new_vector = quad_grid[row][col - 1].right.circ_cent
			voronoi_edges.append(VoronoiEdge.new(new_vector, quad.left.circ_cent))
			
			if row == quad_grid.size() - 1:
				var normal : Vector2 = quad.bottom_left().direction_to(quad.bottom_right()).tangent()
				var edge_x : float = quad.bottom.circ_cent.x + (normal.x * ((height - quad.bottom.circ_cent.y) / normal.y))
				new_vector = Vector2(edge_x, height)
			else:
				new_vector = quad_grid[row + 1][col].top.circ_cent
			voronoi_edges.append(VoronoiEdge.new(new_vector, quad.bottom.circ_cent))
				
			if col == quad_grid[row].size() - 1:
				var normal : Vector2 = quad.bottom_right().direction_to(quad.top_right()).tangent()
				var edge_y : float = quad.left.circ_cent.y + (normal.y * ((width - quad.left.circ_cent.x) / normal.x))
				new_vector = Vector2(width, edge_y)
			else:
				new_vector = quad_grid[row][col + 1].left.circ_cent
			voronoi_edges.append(VoronoiEdge.new(new_vector, quad.right.circ_cent))
			

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
	var pink = Color(1.0, 0.7, 0.7, 1.0)
	# Show points:
	for quad_row in quad_grid:
		for quad in quad_row:
			var tri_top : GridTriangle = quad.top
			var tri_bottom : GridTriangle = quad.bottom
			tri_top.draw(self, white)
			tri_bottom.draw(self, white)

	for edge in voronoi_edges:
		edge.draw(self, pink)
