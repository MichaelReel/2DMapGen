extends TextureRect

const COOL_DOWN : float = 1.000
const ZOOM_SPEED : float = 0.05
const ZOOM_MAX : float = 1.3
const ZOOM_MIN : float = ZOOM_SPEED

const POINT_SPACE : float = 0.1

onready var POINTS_WIDE : int = int(1.0 / POINT_SPACE)
onready var POINTS_TALL : int = int(1.0 / POINT_SPACE)

const IMG1_PATH : String = "res://sample/grid.png"
const IMG2_PATH : String = "res://sample/human.png"

var cool_down := COOL_DOWN
var zoom := 0.4

func _ready():
	material.set_shader_param("human", _get_data_texture())

func _process(delta):
	# Get shader properties
	var mouse = get_global_mouse_position() / get_rect().size;
	var mat : ShaderMaterial = material
	
	# Set shader properties
	mat.set_shader_param("Mouse", mouse)
	mat.set_shader_param("Zoom", zoom)
	
#	# Debug
#	cool_down -= delta
#	if cool_down <= 0.0:
#		print ("cursor: ", str(mouse))
#		cool_down += COOL_DOWN
	

func _gui_input(event : InputEvent):
	if event is InputEventMouseButton:
		var emb := event as InputEventMouseButton
		if emb.is_pressed():
			if emb.get_button_index() == BUTTON_WHEEL_UP:
				zoom = min(ZOOM_MAX, zoom + ZOOM_SPEED)
			if emb.get_button_index() == BUTTON_WHEEL_DOWN:
				zoom = max(ZOOM_MIN, zoom - ZOOM_SPEED)
		
func _get_data_texture() -> ImageTexture:
	var data := ImageTexture.new()
	var img := Image.new()
	var data_points := StreamPeerBuffer.new()
	
	img.create(POINTS_WIDE, POINTS_TALL, false, Image.FORMAT_RGF)
	# Create initial array of points
	for y_index in range(0, POINTS_TALL):
		var y := range_lerp(y_index, 0, POINTS_TALL, 0, 1.0)
		for x_index in range(0, POINTS_WIDE):
			var x := range_lerp(x_index, 0, POINTS_WIDE, 0, 1.0)
			var point_data := Vector2(x + randf() * POINT_SPACE, y + randf() * POINT_SPACE)
			data_points.put_float(point_data.x)
			data_points.put_float(point_data.y)
			
	var byte_count = data_points.get_available_bytes()
	print (str(byte_count) + " bytes available")
	img.create_from_data(POINTS_WIDE, POINTS_TALL, false, Image.FORMAT_RGF, data_points.data_array)
	data.create_from_image(img, 0)
	
	return data
