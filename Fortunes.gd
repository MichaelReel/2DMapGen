extends TextureRect

const POINT_COUNT = 100
const MIN_PROX = 50
const MIN_SQRD_PROX = MIN_PROX * MIN_PROX
const MARGIN = 50
const TRY_LIMIT = 10000

onready var width : int = rect_size.x
onready var height : int = rect_size.y
onready var vector_array : VectorArray = VectorArray.new()

class VectorArray:
	var x_sorted : Array = []
	
	func insert(entry : Vector2) -> bool:
		var x_ind = x_sorted.bsearch_custom(entry, VectorArray, "_sort_x")
		# Check proximity to closest along x and y
		if _local_too_near(entry):
			return false
		# Okay, insert 
		x_sorted.insert(x_ind, entry)
		return true
	
	static func _sort_x (a : Vector2, b : Vector2):
		return a.x < b.x
	
	func _local_too_near(entry : Vector2) -> bool:
		# find any other vectors within the given hortz range
		var x_start_ind = x_sorted.bsearch_custom(entry + Vector2(-MIN_PROX, 0), VectorArray, "_sort_x")
		var x_end_ind = x_sorted.bsearch_custom(entry + Vector2(MIN_PROX, 0), VectorArray, "_sort_x")
		
		for by_x in x_sorted.slice(x_start_ind, x_end_ind):
			if _too_near(entry, by_x):
				return true
		return false
	
	func _too_near(a : Vector2, b : Vector2):
		return a.distance_squared_to(b) < MIN_SQRD_PROX

func _ready():
#	# Create a quick background texture (mostly for debug/contrast)
#	var imageTexture := ImageTexture.new()
#	var noise : OpenSimplexNoise = OpenSimplexNoise.new()
#	var noiseImage : Image = noise.get_image(width, height)
#	imageTexture.create_from_image(noiseImage)
#	self.texture = imageTexture
	
	# First create a set of "sites". Should be random but fairly well spread out
	var x_extent : int =  width - MARGIN * 2
	var y_extent : int =  height - MARGIN * 2
	for _i in range(0, POINT_COUNT):
		var tries_left : int = POINT_COUNT
		var inserted : bool = false
		while not inserted and tries_left > 0:
			inserted = vector_array.insert(Vector2(MARGIN + randi() % x_extent, MARGIN + randi() % y_extent))
			tries_left -= 1
		if tries_left <= 0:
			print ("Try limit reached, recommend lowering POINT_COUNT or MIN_PROX")
			break
	
	
func _draw():
	# Take advantage of the inherited CanvasItem capability
	# This does not draw onto the image texture
	var yellow = Color(1.0, 1.0, 0.0, 1.0)
	var pink = Color(1.0, 0.7, 0.7, 1.0)
	# Show points:
	for p in vector_array.x_sorted:
		draw_circle(p, 1.5, yellow)

