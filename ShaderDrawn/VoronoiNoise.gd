extends TextureRect

const ZOOM_SPEED : float = 0.05
const ZOOM_MAX : float = 1.3
const ZOOM_MIN : float = ZOOM_SPEED

const POINT_SPACE : float = 0.025

onready var POINTS_WIDE : int = int(1.0 / POINT_SPACE)
onready var POINTS_TALL : int = int(1.0 / POINT_SPACE)

var zoom := 0.4
var t := 0.0

func _ready():
	material.set_shader_param("PointSpace", POINT_SPACE)

func _process(delta):
	t += delta
	# Get shader properties
	var mouse = get_global_mouse_position() / get_rect().size;
	var mat : ShaderMaterial = material
	
	# Set shader properties
	mat.set_shader_param("PointData", _get_data_texture(t))
	mat.set_shader_param("PointColor", _get_color_texture(t))
	mat.set_shader_param("Mouse", mouse)
	mat.set_shader_param("Zoom", zoom)

func _gui_input(event : InputEvent):
	if event is InputEventMouseButton:
		var emb := event as InputEventMouseButton
		if emb.is_pressed():
			if emb.get_button_index() == BUTTON_WHEEL_UP:
				zoom = min(ZOOM_MAX, zoom + ZOOM_SPEED)
			if emb.get_button_index() == BUTTON_WHEEL_DOWN:
				zoom = max(ZOOM_MIN, zoom - ZOOM_SPEED)

func _get_data_texture(time : float) -> ImageTexture:
	var data := ImageTexture.new()
	var img := Image.new()
	var data_points := StreamPeerBuffer.new()
	var noise : OpenSimplexNoise = OpenSimplexNoise.new()
	noise.seed = 10
	noise.period = 3.0
	
	img.create(POINTS_WIDE, POINTS_TALL, false, Image.FORMAT_RGF)
	# Create initial array of points
	for y_index in range(0, POINTS_TALL):
		var y := range_lerp(y_index, 0, POINTS_TALL, 0, 1.0)
		for x_index in range(0, POINTS_WIDE):
			var x := range_lerp(x_index, 0, POINTS_WIDE, 0, 1.0)
			data_points.put_float(x + noise.get_noise_2d(x_index + time, y_index) * POINT_SPACE)
			data_points.put_float(y + noise.get_noise_2d(x_index, y_index + time) * POINT_SPACE)
			
	var byte_count = data_points.get_available_bytes()
	img.create_from_data(POINTS_WIDE, POINTS_TALL, false, Image.FORMAT_RGF, data_points.data_array)
	data.create_from_image(img, 0)
	
	return data

func _get_color_texture(time : float) -> ImageTexture:
	var data := ImageTexture.new()
	var img := Image.new()
	var data_points := StreamPeerBuffer.new()
	var noise : OpenSimplexNoise = OpenSimplexNoise.new()
	noise.period = 5.0
	
	img.create(POINTS_WIDE, POINTS_TALL, false, Image.FORMAT_RGF)
	# Create initial array of points
	for y_index in range(0, POINTS_TALL):
		for x_index in range(0, POINTS_WIDE):
			data_points.put_float(noise.get_noise_2d(x_index + time, y_index - time) / 5.0 + 0.2)
			data_points.put_float(noise.get_noise_2d(x_index + POINTS_WIDE, y_index + time) / 3.0 + 0.5)
			data_points.put_float(noise.get_noise_2d(x_index - time, y_index + POINTS_TALL) / 5.0 + 0.3)
			
	var byte_count = data_points.get_available_bytes()
	img.create_from_data(POINTS_WIDE, POINTS_TALL, false, Image.FORMAT_RGBF, data_points.data_array)
	data.create_from_image(img, 0)
	
	return data
