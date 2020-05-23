extends TextureRect

const POINT_COUNT = 100
const MIN_PROX = 50
const MIN_SQRD_PROX = MIN_PROX * MIN_PROX
const MARGIN = 25
const TRY_LIMIT = 10000

onready var width : int = rect_size.x
onready var height : int = rect_size.y
onready var Algorithm = load("res://lib/FortunesVoronoi01.gd")

var init_sites : SortedVectorArray
var result_sites : Array

class SortedVectorArray:
	var x_sorted : Array = []
	
	func insert(entry : Vector2, enforce_distancing : bool = false) -> bool:
		var x_ind = x_sorted.bsearch_custom(entry, SortedVectorArray, "_sort_x")
		# Check proximity to closest along x and y
		if enforce_distancing and _local_too_near(entry):
			return false
		# Okay, insert 
		x_sorted.insert(x_ind, entry)
		return true
	
	static func _sort_x (a : Vector2, b : Vector2):
		return a.x < b.x
	
	func _local_too_near(entry : Vector2) -> bool:
		# find any other vectors within the given hortz range
		var x_start_ind = x_sorted.bsearch_custom(entry + Vector2(-MIN_PROX, 0), self, "_sort_x")
		var x_end_ind = x_sorted.bsearch_custom(entry + Vector2(MIN_PROX, 0), self, "_sort_x")
		
		for by_x in x_sorted.slice(x_start_ind, x_end_ind):
			if _too_near(entry, by_x):
				return true
		return false
	
	func _too_near(a : Vector2, b : Vector2):
		return a.distance_squared_to(b) < MIN_SQRD_PROX

func _ready():
	init_sites = create_sites(0)
	
	var algorithm = Algorithm.new()
	
	algorithm.set_bounds_2D(Rect2(Vector2.ZERO, rect_size))
	result_sites = algorithm.get_voronoi_2D(init_sites.x_sorted)
	
func _draw():
	# Take advantage of the inherited CanvasItem capability
	# This does not draw onto the image texture
	var yellow = Color(1.0, 1.0, 0.0, 1.0)
	var pink = Color(1.0, 0.7, 0.7, 1.0)
	# Show points:

	for rsite in result_sites:
		draw_circle(rsite.nucleus, 1.5, pink)
		draw_polyline(rsite.bounds, yellow, 1.5)

func create_sites(rseed : int):
	seed(rseed)
	var site_list : SortedVectorArray = SortedVectorArray.new()
	# Create a set of "sites". Should be random but fairly well spread out
	var x_extent : int =  width - MARGIN * 2
	var y_extent : int =  height - MARGIN * 2
	for _i in range(0, POINT_COUNT):
		var tries_left : int = POINT_COUNT
		var inserted : bool = false
		while not inserted and tries_left > 0:
			inserted = site_list.insert(Vector2(MARGIN + randi() % x_extent, MARGIN + randi() % y_extent), true)
			tries_left -= 1
		if tries_left <= 0:
			print ("Try limit reached, recommend lowering POINT_COUNT or MIN_PROX")
			break
	return site_list
