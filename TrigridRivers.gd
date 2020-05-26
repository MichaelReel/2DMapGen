extends TextureRect

const TRI_SIDE : float = 50.0
const TRI_HEIGHT : float = sqrt( 0.75 * (TRI_SIDE * TRI_SIDE))
const MIN_DEPTH : float = 1.0
const START_DEPTH : float = 25.0
const DEPTH_CHANGE : float = 1.0
const RADIUS : float = TRI_SIDE * sin(PI / 6) / 2

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
	
	func draw_guides(canvas : CanvasItem, color : Color):
		for row_ind in range (0, points.size()):
			for col_ind in range (0, points[row_ind].size()):
				var point = points[row_ind][col_ind]
				canvas.draw_circle(point.pos, 2.0, color)
				for conn in point.connections:
					canvas.draw_line(point.pos, conn.pos, color, 0.5)
	
	func draw_flow_debug(canvas : CanvasItem, dcolor : Color):
		for source in sources:
			canvas.draw_circle(source.pos, 3.0, dcolor)
			var point : TriPoint = source
			while not point.drawn:
				canvas.draw_line(point.pos, point.downstream.pos, dcolor, point.depth)
				point.drawn = true
				if point.downstream == point:
					break
				point = point.downstream
	
	func draw_flows(canvas : CanvasItem, color : Color):
		# Attempt to draw river curves
		for source in sources:
			var point : TriPoint = source
			var last_pos : Vector2 = point.pos - (point.downstream.pos - point.pos)
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
		
		if ccw(a, b, c) == 0:
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

			canvas.draw_arc(center, RADIUS * 1.125, start_angle, end_angle, RADIUS * 1.25, color, line_width)
		else:
#			# Open obtuse equalateral curve
			var center : Vector2 = a + (c - b)
			var start_angle : float = (mid_ab - center).angle()
			var end_angle : float = (mid_bc - center).angle()
			# Angles that go through +- PI need modifying
			if (end_angle - start_angle) > PI:
				end_angle -= 2 * PI
			if (end_angle - start_angle) < -PI:
				end_angle += 2 * PI
			canvas.draw_arc(center, TRI_HEIGHT, start_angle, end_angle, 20, color, line_width)

	static func ccw(a, b, c):
		# Returns -1: clockwise, 0: collinear, 1:anti-clockwise 
		var area2 = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
		if area2 < 0:
			return -1
		elif area2 > 0:
			return +1
		else:
			return 0

func _ready():
	print (str(Vector2.LEFT.angle()))
	print (str(Vector2.UP.angle()))
	print (str(Vector2.RIGHT.angle()))
	print (str(Vector2.DOWN.angle()))
	
	print (str(Vector2.RIGHT.angle_to(Vector2.LEFT)))
	print (str(Vector2.RIGHT.angle_to(Vector2.UP)))
	print (str(Vector2.RIGHT.angle_to(Vector2.RIGHT)))
	print (str(Vector2.RIGHT.angle_to(Vector2.DOWN)))
	
	var right_down := Vector2.RIGHT + Vector2.DOWN
	print (str(right_down))
	print (str(right_down.angle_to(Vector2.LEFT)))
	print (str(right_down.angle_to(Vector2.UP)))
	print (str(right_down.angle_to(Vector2.RIGHT)))
	print (str(right_down.angle_to(Vector2.DOWN)))
	
	seed(1)
	grid = TriGrid.new(width, height)
	grid.flow_from(0, 6, START_DEPTH)
	
func _draw():
	
#	var center := Vector2(width / 4, height / 2)
#	var radius := width / 8
#	var start_angle := PI
#	var end_angle := PI / 4
#	var points : int = radius * 1.25
#	var color := Color(0.5, 0.5, 1.0, 1.0)
#	var line_width := height / 10
#	var antialiased := false
#
#	draw_arc(center, radius, start_angle, end_angle, points, color, line_width, antialiased)
#	center = Vector2(3 * width / 4, height / 2)
#	start_angle = -3 * PI / 4
#	end_angle = -2 * PI + 3 * PI / 4
#	draw_arc(center, radius, start_angle, end_angle, points, color, line_width, antialiased)
	
#	grid.draw_guides(self, Color(1.0, 1.0, 1.0, 0.1))
#	grid.draw_flow_debug(self, Color(0.0, 1.0, 0.5, 0.1))
	grid.draw_flows(self, Color(0.0, 0.5, 1.0, 1.0))
