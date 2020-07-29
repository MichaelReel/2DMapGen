extends TextureRect

const RANDOM_SEED := 41

const TRI_SIDE : float = 40.0 # Odd numbers behave badly
const TRI_HEIGHT : float = sqrt( 0.75 * (TRI_SIDE * TRI_SIDE))
const MIN_DEPTH : float = 0.0
const START_DEPTH : float = 36.0
const DEPTH_CHANGE : float = 0.5
const RADIUS : float = TRI_SIDE * sin(PI / 6) / 2
const DENSITY : float = 0.15

onready var width := rect_size.x
onready var height := rect_size.y
onready var grid : TriGrid

class TriPoint:
	# A point in a trianglular grid
	var pos : Vector2
	var col : int
	var row : int
	var connections : Array
	var upstream : Array
	var contour : Array
	var downstream : TriPoint
	var depth : float
	var drawn : bool
	var source : bool
	var bank : bool
	
	func _init(v, x, y):
		pos = v
		col = x
		row = y
		connections = []
		upstream = []
		contour = []
		downstream = null
		depth = -DEPTH_CHANGE
		drawn = false
		source = false
		bank = false
	
	func set_neighbors(neighbors : Array):
		connections = neighbors
		for neighbor in neighbors:
			neighbor._add(self)
	
	func _add(connection : TriPoint):
		connections.append(connection)
	
	func is_river() -> bool:
		return downstream != null or not upstream.empty()


class TriGrid:
	# A grid of points that are triangular in placement
	var points := []
	var sources := []
	
	var debug_points := []
	
	func _init(width : float, height : float):
		var row_ind : int = 0
		for y in range (0.0, height, TRI_HEIGHT):
			var points_row := []
			var ind_offset := (row_ind % 2) * 2 - 1
			var offset := (row_ind % 2) * (TRI_SIDE / 2)
			var col_ind : int = 0
			for x in range (offset, width, TRI_SIDE):
				# Create point in grid
				var new_point = TriPoint.new(Vector2(x, y), col_ind, row_ind)
				points_row.append(new_point)
				
				# Form connections
				var neighbors = []
				if col_ind > 0:
					neighbors.append(points_row[col_ind - 1])
				if row_ind > 0 and col_ind < points[row_ind - 1].size():
					neighbors.append(points[row_ind - 1][col_ind])
				if row_ind > 0 and col_ind + ind_offset >= 0 and col_ind + ind_offset < points[row_ind - 1].size():
					neighbors.append(points[row_ind - 1][col_ind + ind_offset])
				new_point.set_neighbors(neighbors)
				
				# Next col
				col_ind += 1
				
			points.append(points_row)
			
			#next row
			row_ind += 1
			
		# Want to find a pseudorandom starting location on the edge
		var edges : Array = [] + points[0] + points[points.size() - 1]
		for row in points.slice(1, points.size() - 2):
			edges += [row[0], row[row.size() - 1]]
		edges.shuffle()
		var start : TriPoint = edges[0]
		
		# Off grid point so river always leaves
		var off_grid : TriPoint = null
		if start.row == 0:
			off_grid = TriPoint.new(start.pos + Vector2.UP * TRI_HEIGHT, 0, 0)
			off_grid.downstream = off_grid
		
		flow_from(start.col, start.row, START_DEPTH, off_grid)
		
		# Remove some random sources depending on density
		sources.shuffle()
		for dumps in range(0, (1.0 - DENSITY) * sources.size()):
			_dry_source(sources.pop_back())
		
		# Tributraries should not be wide channel
		for source in sources:
			# Rationalise the water from this source
			_thin_source(source)
		
		# Mark out river valley sides points
		for source in sources:
			_create_bank_points(source)
		
		# For each triangle, connect banks if there are 2 banks and a river
		var y = 0
		while y < points.size():
			var x : int = 0
			while x < points[y].size():
				if y % 2 == 0:
					# Even rows |/|
					_test_bank_triangle([[x    , y],[x + 1, y    ],[x, y + 1]])
					_test_bank_triangle([[x + 1, y],[x + 1, y + 1],[x, y + 1]])
				else:
					# Odd rows |\|
					_test_bank_triangle([[x, y],[x + 1, y    ],[x + 1, y + 1]])
					_test_bank_triangle([[x, y],[x + 1, y + 1],[x    , y + 1]])
				x += 1
			y += 1
	
	func _dry_source(source_point : TriPoint):
		source_point.source = false
		source_point.upstream.clear()
		source_point.downstream.upstream.erase(source_point)
		if source_point.downstream.upstream.empty():
			_dry_source(source_point.downstream)
		source_point.downstream = null
	
	func _thin_source(source : TriPoint):
		var new_depth = DEPTH_CHANGE
		for upstr in source.upstream:
			new_depth = max(new_depth, upstr.depth + DEPTH_CHANGE)
		
		source.depth = new_depth
		
		if source.downstream != source:
			_thin_source(source.downstream)
	
	func _create_bank_points(source : TriPoint):
		for n in source.connections:
			if not n.is_river():
				n.bank = true
		if source.downstream != source:
			_create_bank_points(source.downstream)
	
	func _test_bank_triangle(tri_indices : Array):
		var banks : Array = []
		var tri_vec : Vector2 = Vector2()
		for tri_col_row in tri_indices:
			var xi : int = tri_col_row[0]
			var yi : int = tri_col_row[1]
			# If a point doesn't exist, it's not a triangle!
			if yi >= points.size():
				return
			if xi >= points[yi].size():
				return
			# We only want the right kind of points in our triangle
			var corner : TriPoint = points[yi][xi]
			if not corner.bank and not corner.is_river():
				return
			if corner.bank:
				banks.append(corner)
			tri_vec += points[yi][xi].pos
		
		# If this the right kind of triangle?
		if banks.size() != 2:
			return
		
		banks[0].contour.append(banks[1])
		banks[1].contour.append(banks[0])
		
		debug_points.append(tri_vec / 3.0)
	
	func flow_from(col : int, row : int, depth : float, downstream = null):
		# Recursive algorithm to visit unvisited points via connections
		
		# Mark this point as visited
		var point = points[row][col]
		point.depth = depth
		if downstream != null:
			point.downstream = downstream
			downstream.upstream.append(point)
		else:
			point.downstream = point # Sink
		
		# Record this point as a river source
		if point.depth <= MIN_DEPTH:
			point.source = true
			sources.append(point)
			return
			
		# Get a list of visitable sources
		var available = []
		for conn in point.connections:
			if conn.downstream == null:
				available.append(conn)
		
		# If there's nowhere to go, then this is kindof a source
		if available.empty():
			point.source = true
			sources.append(point)
			return
		
		# Visit any sources still available in random order
		available.shuffle()
		for conn in available:
			if conn.downstream == null:
				flow_from(conn.col, conn.row, point.depth - DEPTH_CHANGE, point)
	
	func draw_flows(canvas : CanvasItem, color : Color):
		# Attempt to draw river curves
		for source in sources:
			var point : TriPoint = source
			var last_point : TriPoint = point
			while true:
				_draw_connection(canvas, color, last_point.pos, point.pos, point.downstream.pos, last_point.depth)
				point.drawn = true
				if point.downstream == point:
					break
				last_point = point
				point = point.downstream
	
	func _draw_connection(canvas : CanvasItem, color : Color, a : Vector2, b : Vector2, c : Vector2, line_width : float):
		# Draw from the mid point of the 2 lines either a line, or an arc
		var mid_ab = a.linear_interpolate(b, 0.5)
		var mid_bc = b.linear_interpolate(c, 0.5)
		
		if (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) == 0:
			# Collinear points, draw a straight line, then we're done
			canvas.draw_line(mid_ab, mid_bc, color, line_width)
			return
		elif mid_ab.distance_to(mid_bc) <= TRI_SIDE * 0.5:
			# Tight acute equalateral curve
			var center : Vector2 = (a + b + c) / 3
			var start_angle : float = (mid_ab - center).angle()
			var end_angle : float = (mid_bc - center).angle()
			# Angles that go through +- PI need modifying
			if (end_angle - start_angle) > PI:
				end_angle -= 2 * PI
			if (end_angle - start_angle) < -PI:
				end_angle += 2 * PI
			canvas.draw_arc(center, RADIUS, start_angle, end_angle, RADIUS * 2, color, line_width)
		else:
			# Open obtuse equalateral curve
			var center : Vector2 = a + (c - b)
			var start_angle : float = (mid_ab - center).angle()
			var end_angle : float = (mid_bc - center).angle()
			# Angles that go through +- PI need modifying
			if (end_angle - start_angle) > PI:
				end_angle -= 2 * PI
			if (end_angle - start_angle) < -PI:
				end_angle += 2 * PI
			canvas.draw_arc(center, TRI_HEIGHT, start_angle, end_angle, TRI_HEIGHT * 2, color, line_width)
	
	func draw_debug_grid(canvas : CanvasItem, color : Color, point_size : float, line_width : float):
		for row_ind in range (0, points.size()):
			for col_ind in range (0, points[row_ind].size()):
				var point : TriPoint = points[row_ind][col_ind]
##				if point.depth <= 0.0 and not point.source :
#				if point.downstream == null and point.upstream.empty():
				if point.bank:
					canvas.draw_circle(point.pos, point_size, color)
				for conn in point.connections:
					canvas.draw_line(point.pos, conn.pos, color, line_width)
					
	func draw_debug_points(canvas : CanvasItem, color : Color, point_size : float):
		for debug_point in debug_points:
			canvas.draw_circle(debug_point, point_size, color)
		for row in points:
			for point in row:
				for contour_point in point.contour:
					canvas.draw_line(point.pos, contour_point.pos, color, point_size)

func _ready():
	seed(RANDOM_SEED)
	grid = TriGrid.new(width, height)
	
func _draw():
	draw_rect(get_rect(), Color(0.2, 0.4, 0.2, 1.0))
#	grid.draw_debug_grid(self, Color(0.1, 0.1, 0.1, 0.7), 5.0, 0.5)
	grid.draw_flows(self, Color(0.0, 0.5, 1.0, 1.0))
	grid.draw_debug_points(self, Color(0.4, 0.2, 0.2), 3.0)
