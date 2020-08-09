extends TextureRect

const COOL_DOWN : float = 1.000
const ZOOM_SPEED : float = 0.05
const ZOOM_MAX : float = 1.3
const ZOOM_MIN : float = ZOOM_SPEED

var cool_down := COOL_DOWN
var zoom := 0.4

func _process(delta):
	# Get shader properties
	var mouse = get_global_mouse_position() / get_rect().size;
	var mat : ShaderMaterial = material
	
	
	# Set shader properties
	mat.set_shader_param("Mouse", mouse)
	mat.set_shader_param("Zoom", zoom)
	
	# Debug
	cool_down -= delta
	if cool_down <= 0.0:
		print ("cursor: ", str(mouse))
		cool_down += COOL_DOWN
	

func _gui_input(event : InputEvent):
	if event is InputEventMouseButton:
		var emb := event as InputEventMouseButton
		if emb.is_pressed():
			if emb.get_button_index() == BUTTON_WHEEL_UP:
				zoom = min(ZOOM_MAX, zoom + ZOOM_SPEED)
			if emb.get_button_index() == BUTTON_WHEEL_DOWN:
				zoom = max(ZOOM_MIN, zoom - ZOOM_SPEED)
		
