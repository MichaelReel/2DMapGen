extends TextureRect

onready var width : int = rect_size.x
onready var height : int = rect_size.y
onready var image := Image.new()
onready var road_workers := []
onready var ready := false

const BACK_GROUND := Color8(32, 128, 32, 255)
const UNIT_SIZE := 30
const MAX_UNITS := 2
const TRAVEL_MIN := 200
const TRAVEL_MAX := 250

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
		block_dis = UNIT_SIZE * (randi() % MAX_UNITS + 1)
		
	func travel_forward(image : Image, worker_list : Array) -> bool:
		pos += dir
		dis += 1
		block_dis -= 1
		
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
		if block_dis <= 0:
			if dis >= TRAVEL_MAX:
				return false
				
			worker_list.append(RoadWorker.new(pos, dir.tangent(), col.lightened(0.1), dis))
			worker_list.append(RoadWorker.new(pos, dir.tangent().reflect(dir), col.lightened(0.1), dis))
			
			block_dis = UNIT_SIZE * (randi() % MAX_UNITS + 1)
		
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
