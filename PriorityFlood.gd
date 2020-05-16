extends TextureRect

class Pixel:
	# Notes:
	# - Using pixels for height, closed, water
	# - With Red as Height, Green as Closed, Blue as Water
	
	var image : Image
	var pos : Vector2
	
	func _init(i: Image, p: Vector2):
		self.image = i
		self.pos = p
	
	func close():
		var col := image.get_pixelv(pos)
		col.g = 1.0
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
	var image : Image
	
	func _init(i : Image):
		self.image = i
	
	static func sort(a: Pixel, b: Pixel) -> bool:
		return a.height() > b.height()
	
	func insert(pos : Vector2) -> Pixel:
		var new_pos := Pixel.new(self.image, pos)
		var index := priorityList.bsearch_custom(new_pos, ImageHeightSorter, "sort")
		priorityList.insert(index, new_pos)
		new_pos.close()
		return new_pos
	
	func open() -> bool:
		return not priorityList.empty()
	
	func pop() -> Pixel:
		var pixel = priorityList.pop_back()
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
		
		return ns
	
	func debug() -> String:
		var output := ""
		for vect in priorityList:
			output += "{" + str(vect.pos)
			output += "," + str(vect.image.get_pixelv(vect.pos).r) +"}"
			output += ","
		return output

func _ready():
	var imageTexture := ImageTexture.new()
	var noise : OpenSimplexNoise = OpenSimplexNoise.new()
	var width : int = -self.margin_right
	var height : int = -self.margin_bottom
	
	# Configure noise
	noise.seed = randi()
	noise.octaves = 4
	noise.period = 200.0
	noise.persistence = 1.1
	
	var noiseImage : Image = noise.get_image(width, height)
	
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
		sorter.insert(Vector2(0, y))
		sorter.insert(Vector2(x_max, y))
	var y_max := noiseImage.get_height() - 1
	for x in range(1, x_max):
		sorter.insert(Vector2(x, 0))
		sorter.insert(Vector2(x, y_max))
	
	# Start flooding
	while sorter.open():
		var c = sorter.pop()
		var ns = sorter.get_open_neighbours(c.pos)
		for pos in ns:
			var n = sorter.insert(pos)
			n.flood(c.water())
	noiseImage.unlock()
	
	# Strip closed flags
	noiseImage.lock()
	for y in range(0, noiseImage.get_height()):
		for x in range(0, noiseImage.get_width()):
			var col := noiseImage.get_pixel(x, y)
			col.g = col.r
			if col.b == col.r:
				col.b = 0.0
			noiseImage.set_pixel(x, y, col)
	noiseImage.unlock()
	
	imageTexture.create_from_image(noiseImage)
	self.texture = imageTexture
	
	imageTexture.resource_name = "The created texture!"
	print(self.texture.resource_name)
	
	pass
