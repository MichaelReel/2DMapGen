extends TextureRect

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

	var noiseImage : Image = noise.get_image(-self.margin_right, -self.margin_bottom)

	imageTexture.create_from_image(noiseImage)
	self.texture = imageTexture
	
	imageTexture.resource_name = "The created texture!"
	print(self.texture.resource_name)
	
	pass
