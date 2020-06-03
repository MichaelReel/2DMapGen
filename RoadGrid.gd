extends TextureRect

onready var width : int = rect_size.x
onready var height : int = rect_size.y
onready var image := Image.new()
onready var road_workers := []
onready var ready := false

const BACK_GROUND := Color8(32, 128, 32, 255)
const SPLIT_MIN := 50
const TRAVEL_MIN := 250

class RoadWorker:
	var pos : Vector2
	var dir : Vector2
	var col : Color
	var dis : int
	var block_dis : int = 0
	
	func _init(start : Vector2, direction : Vector2, color : Color, distance : int = 0):
		pos = start
		dir = direction
		col = color
		dis = distance
		
	func travel_forward(image : Image, worker_list : Array) -> bool:
		pos += dir
		dis += 1
		block_dis += 1
		
		# Are we still in bounds?
		var bounds := Rect2(Vector2(), image.get_size())
		if not bounds.has_point(pos):
			return false
		
		# Have we encountered an existing road?
		var back := BACK_GROUND
		var plot := image.get_pixelv(pos)
		if not plot.is_equal_approx(back):
			return false
		
		# Lay down some road
		image.set_pixelv(pos, col)
		
		# Have we gone far enough to do something else?
		if block_dis == SPLIT_MIN:
			worker_list.append(RoadWorker.new(pos, dir.tangent(), col.lightened(0.1), dis))
			block_dis = 0
		
			if dis >= TRAVEL_MIN:
				return false
		
		return true

func _ready():
	image.create(width, height, false, Image.FORMAT_RGBA8)
	
	var road := Color(0.1, 0.1, 0.1, 1.0)
	var start = Vector2(width / 2, height / 2)

	image.fill(BACK_GROUND)
	
	road_workers.append(RoadWorker.new(start, Vector2.UP, road))
	road_workers.append(RoadWorker.new(start, Vector2.RIGHT, road))
	road_workers.append(RoadWorker.new(start, Vector2.LEFT, road))
	road_workers.append(RoadWorker.new(start, Vector2.DOWN, road))
	
	ready = true

func _process(delta):
	if not ready:
		return
	
	var drop_list = []
	image.lock()

	for worker in road_workers:
		var success : bool = worker.travel_forward(image, road_workers)
		if not success:
			drop_list.append(worker)

	image.unlock()
	
	for worker in drop_list:
		road_workers.erase(worker)
	 
	var imageTexture := ImageTexture.new()
	imageTexture.create_from_image(image)
	texture = imageTexture
