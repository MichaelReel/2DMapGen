extends TextureRect

const RANDOM_SEED := 41

const TRI_SIDE : float = 30.0
const TRI_HEIGHT : float = sqrt( 0.75 * (TRI_SIDE * TRI_SIDE))
const MIN_DEPTH : float = 0.0
const START_DEPTH : float = 25.0
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
	var downstream : TriPoint
	var depth : float
	var drawn : bool
	
	func _init(v, x, y):
		pos = v
		col = x
		row = y
		connections = []
		downstream = null
		depth = 0.0
		drawn = false
	
	func set_neighbors(neighbors : Array):
		connections = neighbors
		for neighbor in neighbors:
			neighbor._add(self)
	
	func _add(connection : TriPoint):
		connections.append(connection)


class TriGrid:
	# A grid of points that are triangular in placement
	var points := []
	var sources := []
	
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
			sources.pop_back()
	
	func flow_from(col : int, row : int, depth : float, downstream = null):
		# Recursive algorithm to visit unvisited points via connections
		
		# Mark this point as visited
		var point = points[row][col]
		point.depth = depth
		if downstream != null:
			point.downstream = downstream
		else:
			point.downstream = point # Sink
		
		# Record this point as a river source
		if point.depth <= MIN_DEPTH:
			sources.append(point)
			return
			
		# Get a list of visitable sources
		var available = []
		for conn in point.connections:
			if conn.downstream == null:
				available.append(conn)
		
		# Visit any sources still available in random order
		available.shuffle()
		for conn in available:
			if conn.downstream == null:
				flow_from(conn.col, conn.row, point.depth - DEPTH_CHANGE, point)

	func draw_flows(canvas : CanvasItem, color : Color):
		# Attempt to draw river curves
		for source in sources:
			var point : TriPoint = source
			var last_pos : Vector2 = point.pos
			while true:
				_draw_connection(canvas, color, last_pos, point.pos, point.downstream.pos, point.depth)
				point.drawn = true
				if point.downstream == point:
					break
				last_pos = point.pos
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

func _ready():
	seed(RANDOM_SEED)
	grid = TriGrid.new(width, height)
	
func _draw():
	grid.draw_flows(self, Color(0.0, 0.5, 1.0, 1.0))
