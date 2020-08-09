extends TextureRect

onready var width : int = rect_size.x
onready var height : int = rect_size.y

func _ready():
	var imageTexture := ImageTexture.new()
	var noise : OpenSimplexNoise = OpenSimplexNoise.new()
	imageTexture.create_from_image(noise.get_image(width, height))
	texture = imageTexture
