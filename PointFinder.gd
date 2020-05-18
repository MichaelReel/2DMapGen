extends TextureRect

const NEIGHBOURS : Array = [
	Vector2(-1, -1),
	Vector2(-1,  0),
	Vector2(-1,  1),
	Vector2( 0, -1),
	Vector2( 0,  1),
	Vector2( 1, -1),
	Vector2( 1,  0),
	Vector2( 1,  1),
]
const LEVEL_TOLERANCE : int = 4

var bounds : Rect2


func _ready():
	var imageTexture := ImageTexture.new()
	var noise : OpenSimplexNoise = OpenSimplexNoise.new()
	var width : int = rect_size.x
	var height : int = rect_size.y

	# Configure noise
	var octaves = 2
	var period = 64.0 * octaves
	var persistence = 0.7
	var lacunarity = 4.0

	# Configure noise
	noise.seed = 1
	noise.set_octaves(octaves)
	noise.set_period(period)
	noise.set_persistence(persistence)
	noise.set_lacunarity(lacunarity)
	
	var noiseImage : Image = noise.get_image(width, height)
	bounds = noiseImage.get_used_rect()
	
#	var noiseImage : Image = Image.new()
#	noiseImage.create(width, height, false, Image.FORMAT_RGBA8)
#	noiseImage.lock()
#	for y in range(0, height):
#		for x in range(0, width):
#			var col = lerp(Color(0.4, 0.4, 0.4, 1.0), Color(1.1, 1.1, 1.1, 1.0), noise.get_noise_2d(x, y))
#			noiseImage.set_pixel(x, y, col)
#	noiseImage.unlock()

	imageTexture.create_from_image(noiseImage)
	self.texture = imageTexture
	
	var pointImage : Image = Image.new()
	pointImage.create(width, height, false, Image.FORMAT_RGBA8)

	var peakPoints : Array = []
	var dipPoints : Array = []

	noiseImage.lock()
	pointImage.lock()
	for y in range(0, height):
		for x in range(0, width):
			var point = Vector2(x, y)
#			var col := Color(0.0, 0.0, 0.0, 0.0)
			var col := noiseImage.get_pixelv(point)
			if is_peak_point(point, noiseImage):
				col.g = 0.0
				peakPoints.append(point)
			if is_dip_point(point, noiseImage):
				col.g = 1.0
				dipPoints.append(point)
			pointImage.set_pixelv(point, col)
	pointImage.unlock()
	noiseImage.unlock()

	imageTexture.create_from_image(pointImage)
	self.texture = imageTexture

func is_peak_point(point : Vector2, image : Image) -> bool:
	var r = image.get_pixelv(point).r
	if r <= 0.5:
		return false
	var level_neighbours = 0
	for dxy in NEIGHBOURS:
		var n : Vector2 = point + dxy
		if not bounds.has_point(n):
			return false
		var nr := image.get_pixelv(n).r
		if nr > r:
			return false
		elif nr == r:
			level_neighbours += 1
	if level_neighbours >= LEVEL_TOLERANCE:
		return false
	return true

func is_dip_point(point : Vector2, image : Image) -> bool:
	var r = image.get_pixelv(point).r
	if r > 0.5:
		return false
	var level_neighbours = 0
	for dxy in NEIGHBOURS:
		var n : Vector2 = point + dxy
		if not bounds.has_point(n):
			return false
		var nr := image.get_pixelv(n).r
		if nr < r:
			return false
		elif nr == r:
			level_neighbours += 1
	if level_neighbours >= LEVEL_TOLERANCE:
		return false
	return true
	
