extends TextureRect

func _ready():
	var imageTexture := ImageTexture.new()
	var noiseR : OpenSimplexNoise = OpenSimplexNoise.new()
	var noiseG : OpenSimplexNoise = OpenSimplexNoise.new()
	var noiseB : OpenSimplexNoise = OpenSimplexNoise.new()
	var width : int = rect_size.x
	var height : int = rect_size.y
	var step := 1.0  # Lower == more discrete layers
	var bias := 0.6  # Average "brightness" of colours

	# Configure noise
	noiseR.seed = 1
	noiseR.octaves = 3
	noiseR.period = 100.0
	noiseR.persistence = 0.9
	
	noiseG.seed = 2
	noiseG.octaves = 3
	noiseG.period = 100.0
	noiseG.persistence = 0.9
	
	noiseB.seed = 3
	noiseB.octaves = 3
	noiseB.period = 100.0
	noiseB.persistence = 0.9

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
	
	imageTexture.resource_name = "The created texture!"
	print(self.texture.resource_name)
	
	pass
