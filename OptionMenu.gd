extends MenuButton

const CATEGORIES := {
	"Pixel Drawn" : "res://PixelDrawn",
	"Vector Drawn" : "res://VectorDrawn",
	"Shader Drawn" : "res://ShaderDrawn",
}

var menu_selections : Dictionary = {}
onready var display_node := get_parent().get_node("DisplayControl")

func _ready():
	var popup := get_popup()
	var dir := Directory.new()
	popup.set_allow_search(true)
	popup.connect("id_pressed", self, "popup_menu_selected")
	
	var id = 0
	for category in CATEGORIES.keys():
		var path : String = CATEGORIES[category]
		popup.add_item(category, id)
		popup.set_item_disabled(id, true)
		id += 1
		
		# Get list from path and add to menu
		if dir.open(path) == OK:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.match("*.*scn"):
					var scene_name : String = file_name.rsplit(".", true, 1)[0]
					var scene_path : String = path + "/" + file_name
					popup.add_item(scene_name, id)
					menu_selections[id] = scene_path
					id += 1
				file_name = dir.get_next()
			dir.list_dir_end()
		else:
			print ("Couldn't read directory: " + path)

func popup_menu_selected(id : int):
	var scene_path : String = menu_selections[id]
	var scene_resource : Resource = load(scene_path)
	var scene = scene_resource.instance()
	_clear_free_children(display_node)
	display_node.add_child(scene)

func _clear_free_children(node : Node):
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
