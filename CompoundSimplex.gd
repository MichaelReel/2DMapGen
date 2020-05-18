extends TextureRect

func _ready():
	var imageTexture := ImageTexture.new()
	var noiseR : OpenSimplexNoise = OpenSimplexNoise.new()
	var noiseG : OpenSimplexNoise = OpenSimplexNoise.new()
	var noiseB : OpenSimplexNoise = OpenSimplexNoise.new()
	var width : int = rect_size.x
	var height : int = rect_size.y
	var step := 1.0  # Lower == more discrete layers
	var bias := 0.5  # Average "brightness" of colours

	var octaves = 3
	var period = 64.0
	var persistence = 0.5
	var lacunarity = 2.0

	# Configure noise
	noiseR.seed = 1
	noiseR.set_octaves(octaves)
	noiseR.set_period(period)
	noiseR.set_persistence(persistence)
	noiseR.set_lacunarity(lacunarity)
	
	noiseG.seed = 2
	noiseG.set_octaves(octaves)
	noiseG.set_period(period)
	noiseG.set_persistence(persistence)
	noiseG.set_lacunarity(lacunarity)
	
	noiseB.seed = 3
	noiseB.set_octaves(octaves)
	noiseB.set_period(period)
	noiseB.set_persistence(persistence)
	noiseB.set_lacunarity(lacunarity)

	var noiseImage : Image = Image.new()
	noiseImage.create(width, height, false, Image.FORMAT_RGBA8)

	noiseImage.lock()
	for y in range(0, height):
		for x in range(0, width):
			var r = stepify( clamp(noiseR.get_noise_2d(x, y) + bias, 0.0, 1.0), step)
			var g = stepify( clamp(noiseG.get_noise_2d(x, y) + bias, 0.0, 1.0), step)
			var b = stepify( clamp(noiseB.get_noise_2d(x, y) + bias, 0.0, 1.0), step)
			var col : Color = Color(r, g, b)
			noiseImage.set_pixel(x, y, col)
	noiseImage.unlock()

	imageTexture.create_from_image(noiseImage)
	self.texture = imageTexture
	imageTexture.resource_name = "Compound Simplex"
	
	pass
