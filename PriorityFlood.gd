extends TextureRect

const REDRAW_PER_LOOP : int = 1000
var drawThread : Thread
var closing : bool = false

class Pixel:
	# Notes:
	# - Using pixels for height, closed, water
	# - With Red as Height, Green as Closed, Blue as Water
	
	var image : Image
	var pos : Vector2
	
	func _init(i: Image, p: Vector2):
		self.image = i
		self.pos = p
	
	func close(c : Pixel):
		var col := image.get_pixelv(pos)
		if c == null:
			col.g = 1.0
		else:
			# Determine direction c is in and set col.g accordingly
			var dirv : Vector2 = self.pos - c.pos
			var dir = ((dirv.angle() / PI) + 1) / 2.5
			col.g = dir
			
			
		image.set_pixelv(pos, col)
	
	func height() -> float:
		var col := image.get_pixelv(pos)
		return col.r
	
	func water() -> float:
		var col := image.get_pixelv(pos)
		return col.b
	
	func flood(h : float):
		var col := image.get_pixelv(pos)
		col.b = max(col.b, h)
		image.set_pixelv(pos, col)

class ImageHeightSorter:
	var priorityList : Array = []
	var plainQueue : Array = []
	var image : Image
	
	func _init(i : Image):
		self.image = i
	
	static func sort(a: Pixel, b: Pixel) -> bool:
		return a.height() > b.height()
	
	func insert(pos: Vector2, c: Pixel):
		var new_pos := Pixel.new(self.image, pos)
		new_pos.close(c)
		
		if c != null and new_pos.water() <= c.water():
			new_pos.flood(c.water())
			plainQueue.append(new_pos)
		else:
			var index := priorityList.bsearch_custom(new_pos, ImageHeightSorter, "sort")
			priorityList.insert(index, new_pos)
	
	func open() -> bool:
		return not priorityList.empty() or not plainQueue.empty()
	
	func pop() -> Pixel:
		var pixel = plainQueue.pop_back()
		if pixel == null:
			pixel = priorityList.pop_back()
		return pixel
		
	func is_closed(pos : Vector2) -> bool:
		var col := image.get_pixelv(pos)
		return col.g > 0.0
	
	func get_open_neighbours(pos : Vector2) -> Array:
		var ns = []
		
		var nx = Vector2(pos.x - 1, pos.y)
		if (pos.x > 0 and not is_closed(nx)):
			ns.append(nx)
			
		var px = Vector2(pos.x + 1, pos.y)
		if (pos.x < image.get_width() - 1 and not is_closed(px)):
			ns.append(px)
		
		var ny = Vector2(pos.x, pos.y - 1)
		if (pos.y > 0 and not is_closed(ny)):
			ns.append(ny)
		
		var py = Vector2(pos.x, pos.y + 1)
		if (pos.y < image.get_height() - 1 and not is_closed(py)):
			ns.append(py)
		
		# Including diagonals has this affect on the algorithm:
		# Takes just over 3 minutes when included (181 seconds)
		# And just under 2 minutes when excluded (113 seconds)
		
		var nxny = Vector2(pos.x - 1, pos.y - 1)
		if (pos.x > 0 and pos.y > 0 and not is_closed(nxny)):
			ns.append(nxny)

		var pxny = Vector2(pos.x + 1, pos.y - 1)
		if (pos.x < image.get_width() - 1 and pos.y > 0 and not is_closed(pxny)):
			ns.append(pxny)

		var nxpy = Vector2(pos.x - 1, pos.y + 1)
		if (pos.x > 0 and pos.y < image.get_height() - 1 and not is_closed(nxpy)):
			ns.append(nxpy)

		var pxpy = Vector2(pos.x + 1, pos.y + 1)
		if (pos.x < image.get_width() - 1 and pos.y < image.get_height() - 1 and not is_closed(pxpy)):
			ns.append(pxpy)
		
		return ns
	
	func debug() -> String:
		var output := ""
		for vect in priorityList:
			output += "{" + str(vect.pos)
			output += "," + str(vect.image.get_pixelv(vect.pos).r) +"}"
			output += ","
		return output

func _ready():
	var noise : OpenSimplexNoise = OpenSimplexNoise.new()
	var width : int = -self.margin_right
	var height : int = -self.margin_bottom
	
	# Configure noise
	noise.seed = randi()
	noise.octaves = 4
	noise.period = 200.0
	noise.persistence = 1.1
	
	var noiseImage : Image = noise.get_image(width, height)
	drawThread = Thread.new()
	drawThread.start(self, "perform_priority_flood", noiseImage)

func _exit_tree():
	closing = true
	drawThread.wait_to_finish()
	
func perform_priority_flood(noiseImage: Image):
	# Convert Image to red only
	noiseImage.lock()
	for y in range(0, noiseImage.get_height()):
		for x in range(0, noiseImage.get_width()):
			var col := noiseImage.get_pixel(x, y)
			col.g = 0.0
			noiseImage.set_pixel(x, y, col)
	noiseImage.unlock()
	
	# Setup start of priority flood
	var sorter := ImageHeightSorter.new(noiseImage)
	noiseImage.lock()
	
	# Add edge pixels to queue
	var x_max := noiseImage.get_width() - 1
	for y in range(0, noiseImage.get_height()):
		sorter.insert(Vector2(0, y), null)
		sorter.insert(Vector2(x_max, y), null)
	var y_max := noiseImage.get_height() - 1
	for x in range(1, x_max):
		sorter.insert(Vector2(x, 0), null)
		sorter.insert(Vector2(x, y_max), null)
	
	var imageTexture := ImageTexture.new()
	# Start flooding
	var redraw = 0
	while sorter.open():
		var c = sorter.pop()
		var ns = sorter.get_open_neighbours(c.pos)
		for pos in ns:
			sorter.insert(pos, c)
		# Draw progress
		redraw -= 1
		if redraw <= 0:
			# Temp unlock the image so we can draw the progress
			noiseImage.unlock()
			
			imageTexture.create_from_image(noiseImage)
			self.texture = imageTexture
			
			redraw = REDRAW_PER_LOOP
			noiseImage.lock()
		if closing:
			break
	noiseImage.unlock()
	
	imageTexture.create_from_image(noiseImage)
	self.texture = imageTexture
	
	# Post processing tidy-up
	noiseImage.lock()
	for y in range(0, noiseImage.get_height()):
		for x in range(0, noiseImage.get_width()):
			var col := noiseImage.get_pixel(x, y)
			if col.b == col.r:
				col = Color(col.r, 1.0, col.r, 1.0)
			else:
				col = Color(col.b, col.b, 1.0, 1.0)
			noiseImage.set_pixel(x, y, col)
	noiseImage.unlock()
	
	imageTexture.create_from_image(noiseImage)
	self.texture = imageTexture
	
