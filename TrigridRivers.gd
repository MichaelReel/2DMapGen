extends TextureRect

const TRI_SIDE : float = 50.0

onready var width := rect_size.x
onready var height := rect_size.y
onready var grid : TriGrid

class TriPoint:
	# A point in a trianglular grid
	var pos : Vector2
	var col : int
	var row : int
	var connections : Array
	
	func _init(v, x, y):
		pos = v
		col = x
		row = y
		connections = []
	
	func set_neighbors(neighbors : Array):
		connections = neighbors
		for neighbor in neighbors:
			neighbor._add(self)
	
	func _add(connection : TriPoint):
		connections.append(connection)
		


class TriGrid:
	# A grid points that are triangular in placement
	var points := []
	
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
				var new_point = TriPoint.new(Vector2(x, y), row_ind, col_ind)
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
	
	func flow_to(col : int, row : int, depth : float):
		# TODO: Recursive algorithm to visit unvisited points via connections
		pass
	
	func draw_guides(canvas : CanvasItem, color : Color):
		for row_ind in range (0, points.size()):
			for col_ind in range (0, points[row_ind].size()):
				var point = points[row_ind][col_ind]
				canvas.draw_circle(point.pos, 2.0, color)
				for conn in point.connections:
					canvas.draw_line(point.pos, conn.pos, color, 0.5)


func _ready():
#   # This is really just starter debug to check dimension
#	var imageTexture := ImageTexture.new()
#	var noise : OpenSimplexNoise = OpenSimplexNoise.new()
#	var noiseImage : Image = noise.get_image(width, height)
#	imageTexture.create_from_image(noiseImage)
#	self.texture = imageTexture

	grid = TriGrid.new(width, height)
	grid.flow_to(0, 6, 50.0)
	
func _draw():
	grid.draw_guides(self, Color(1.0, 1.0, 1.0, 0.1))
