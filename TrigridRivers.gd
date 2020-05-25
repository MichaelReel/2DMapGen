extends TextureRect

const TRI_SIDE : float = 50.0
const MIN_DEPTH : float = 1.0
const START_DEPTH : float = 25.0
const DEPTH_CHANGE : float = 1.0

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
		var height_diff : float = sqrt( 0.75 * (TRI_SIDE * TRI_SIDE))
		var row_ind : int = 0
		for y in range (0.0, height, height_diff):
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
					
	func draw_flows(canvas : CanvasItem, color : Color):
		for source in sources:
#			canvas.draw_circle(source.pos, 3.0, color)
			var point : TriPoint = source
			while (point.downstream != null and not point.drawn):
				canvas.draw_line(point.pos, point.downstream.pos, color, point.depth)
				point.drawn = true
				point = point.downstream


func _ready():
	seed(1)
	grid = TriGrid.new(width, height)
	grid.flow_from(0, 6, START_DEPTH)
	
func _draw():
#	grid.draw_guides(self, Color(1.0, 1.0, 1.0, 0.1))
	grid.draw_flows(self, Color(0.0, 0.5, 1.0, 1.0))
