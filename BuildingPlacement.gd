extends TextureRect

onready var width : int = rect_size.x
onready var height : int = rect_size.y
onready var image := Image.new()
onready var road_workers := []
onready var building_pool := BuildingPool.new()
onready var ready := false

const BACK_GROUND := Color8(32, 128, 32, 255)
const BUILD_CHANCE := 2

class Building:
	var image : Image 
	var limit : int
	var size : Vector2
	
	func _init(img : Image, lim : int):
		image = img
		limit = lim
		size = image.get_size()

class BuildingPool:
	var buildings : Array
	
	func _init():
		buildings = []
	
	func create():
		# (Probably want some config loading if using this for real)
		# Generate config
		
		# Many small buildings
		buildings.append(Building.new(building_outline(8, 16, Color.aqua), 200))
		buildings.append(Building.new(building_outline(16, 8, Color.aquamarine), 200))
		# Some middle sized buildings
		buildings.append(Building.new(building_outline(24, 16, Color.brown), 60))
		buildings.append(Building.new(building_outline(16, 24, Color.chocolate), 60))
		# A few big buildings
		buildings.append(Building.new(building_outline(24, 32, Color.fuchsia), 20))
		buildings.append(Building.new(building_outline(32, 24, Color.crimson), 20))
		# Unique buildings
		buildings.append(Building.new(building_outline(24, 24, Color.blue), 1))
		buildings.append(Building.new(building_outline(16, 16, Color.blue), 1))
	
	func pop_building() -> Building:
		if buildings.size() <= 0:
			return null
		var build_ind : int = randi() % buildings.size()
		var building = buildings[build_ind]
		buildings[build_ind].limit -= 1
		if buildings[build_ind].limit <= 0:
			buildings.remove(build_ind)
		return building
	
	func push_building(building : Building):
		# Assuming returned building are all by reference D-:
		building.limit += 1
		if building.limit == 1:
			buildings.append(building)

	static func building_outline(w : int, h : int, color : Color) -> Image:
		var img = Image.new()
		img = Image.new()
		img.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(color)
		var light_shade = color.lightened(0.2)
		var dark_shade = color.darkened(0.2)
		img.lock()
		
		for y in range(0, h):
			img.set_pixel(0, y, light_shade)
			img.set_pixel(w - 1, y, dark_shade)
				
		for x in range(0, w):
			img.set_pixel(x, 0, light_shade)
			img.set_pixel(x, h - 1, dark_shade)
		
		img.unlock()
		return img
		

class RoadWorker:
	var pos : Vector2
	var dir : Vector2
	var col : Color
	var dis : int
	var left_block_dis : int = 0
	var right_block_dis : int = 0
	var left_just_split : bool
	var right_just_split : bool
	
	func _init(start : Vector2, direction : Vector2, color : Color, distance : int = 0):
		pos = start
		dir = direction
		col = color
		dis = distance
		left_block_dis = 0
		right_block_dis = 0
		left_just_split = true
		right_just_split = true
		
	func travel_forward(image : Image, worker_list : Array, building_pool : BuildingPool) -> bool:
		pos += dir
		dis += 1
		left_block_dis -= 1
		right_block_dis -= 1
		
		# Are we still in bounds?
		var bounds := Rect2(Vector2(), image.get_size())
		if not bounds.has_point(pos):
			return false
		
		
		image.lock()
		# Have we encountered an existing road/building?
		if not image.get_pixelv(pos).is_equal_approx(BACK_GROUND):
			return false
		
		# Lay down some road
		image.set_pixelv(pos, col)
		image.unlock()
		
		# Have we gone far enough to do something on the left?
		if left_block_dis <= 0:
			var left_dir := dir.tangent()
			var forward_left_dir := left_dir + dir
			
			# Add building, or make road?
			if not left_just_split and randi() % BUILD_CHANCE == 0:
				# Road
				worker_list.append(RoadWorker.new(pos, left_dir, col, dis))
				left_just_split = true
				left_block_dis = 1
			else:
				# Get a building
				var building = building_pool.pop_building()
				if building == null:
					# No buildings left, stop travelling
					return false
				
				# See if we can place it
				var near_corner : Vector2 = pos + left_dir
				var size := Vector2(forward_left_dir.x * building.size.x, forward_left_dir.y * building.size.y)
				if size.x < 0:
					size.x += 1
				if size.y < 0:
					size.y += 1
				var plot_bounds := Rect2(near_corner, size).abs()
				if plot_is_clear(image, plot_bounds, BACK_GROUND):
					# Draw image
					image.blit_rect(building.image, Rect2(Vector2(), building.size), plot_bounds.position)
					left_just_split = false
					var frontage : int = Vector2(building.size.x * dir.x, building.size.y * dir.y).length()
					left_block_dis = frontage
				else:
					building_pool.push_building(building)
					left_block_dis = 1
			
		# Have we gone far enough to do something on the right?
		if right_block_dis <= 0:
			var right_dir := dir.tangent().reflect(dir)
			var forward_right_dir := right_dir + dir
			
			# Add building, or make road?
			if not right_just_split and randi() % BUILD_CHANCE == 0:
				# Road
				worker_list.append(RoadWorker.new(pos, right_dir, col, dis))
				right_just_split = true
				right_block_dis = 1
			else:
				# Get a building
				var building = building_pool.pop_building()
				if building == null:
					# No buildings left, stop travelling
					return false
				
				# See if we can place it
				var near_corner : Vector2 = pos + right_dir
				var size := Vector2(forward_right_dir.x * building.size.x, forward_right_dir.y * building.size.y)
				if size.x < 0:
					size.x += 1
				if size.y < 0:
					size.y += 1
				var plot_bounds := Rect2(near_corner, size).abs()
				if plot_is_clear(image, plot_bounds, BACK_GROUND):
					# Draw image
					image.blit_rect(building.image, Rect2(Vector2(), building.size), plot_bounds.position)
					right_just_split = false
					var frontage : int = Vector2(building.size.x * dir.x, building.size.y * dir.y).length()
					right_block_dis = frontage
				else:
					building_pool.push_building(building)
					right_block_dis = 1
		
		return true

	static func plot_is_clear(image : Image, plot : Rect2, clear_color : Color) -> bool:
		image.lock()
		# Check the edges
		for y in range(plot.position.y, plot.end.y):
			if not image.get_pixel(plot.position.x, y).is_equal_approx(clear_color):
				image.unlock()
				return false
			if not image.get_pixel(plot.end.x, y).is_equal_approx(clear_color):
				image.unlock()
				return false
				
		for x in range(plot.position.x, plot.end.x):
			if not image.get_pixel(x, plot.position.y).is_equal_approx(clear_color):
				image.unlock()
				return false
			if not image.get_pixel(x, plot.end.y).is_equal_approx(clear_color):
				image.unlock()
				return false
		
		image.unlock()
		return true

func _ready():
	image.create(width, height, false, Image.FORMAT_RGBA8)
	building_pool.create()
	
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

	for worker in road_workers:
		var success : bool = worker.travel_forward(image, road_workers, building_pool)
		if not success:
			drop_list.append(worker)
	
	for worker in drop_list:
		road_workers.erase(worker)
	 
	var imageTexture := ImageTexture.new()
	imageTexture.create_from_image(image)
	texture = imageTexture
