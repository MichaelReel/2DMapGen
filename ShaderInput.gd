extends TextureRect

const COOL_DOWN : float = 1.000
var cool_down := COOL_DOWN

func _process(delta):
	var mouse = get_global_mouse_position() / get_rect().size;
	var mat : ShaderMaterial = material
	mat.set_shader_param("Mouse", mouse)
	cool_down -= delta
	if cool_down <= 0.0:
		print ("cursor: ", str(mouse))
		cool_down += COOL_DOWN
	
