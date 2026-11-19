
extends Control

enum Category {
	FACE,
	HAT,
	OUTFIT,
	BEARD
}

@onready var tab_bar: TabBar = $PanelContainer/HBoxContainer/CustomizePanel/TabBar

@onready var grid: GridContainer = $PanelContainer/HBoxContainer/CustomizePanel/ScrollContainer/GridContainer

@onready var done_button: Button = $PanelContainer/HBoxContainer/CustomizePanel/DoneButton

@onready var gnome: GnomeCustomization = $PanelContainer/HBoxContainer/PreviewPanel/SubViewportContainer/SubViewport/gnome_v8

var selected_customization: Dictionary = {
	"face": 0,
	"hat_style": 0,
	"hat": 0,
	"outfit": 0,
	"beard": 0
}

signal customization_finished

func _ready() -> void:
	tab_bar.clear_tabs()
	
	tab_bar.add_tab("Faces")
	tab_bar.add_tab("Hats")
	tab_bar.add_tab("Outfits")
	tab_bar.add_tab("Beards")

	tab_bar.tab_changed.connect(_on_tab_changed)
	done_button.pressed.connect(_on_done_pressed)

	_populate_grid(Category.FACE)


func _on_tab_changed(tab: int) -> void:
	_populate_grid(tab)


func _populate_grid(category: int) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	if category == Category.FACE:
		_populate_face_grid()
		return

	if category == Category.HAT:
		_populate_hat_grid()
		return

	_populate_color_grid(category)

func _populate_color_grid(category: int) -> void:
	var colors := _get_colors(category)

	for i in range(colors.size()):
		var color: Color = colors[i]

		var button := Button.new()
		button.custom_minimum_size = Vector2(75, 75)

		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(8)

		button.add_theme_stylebox_override("normal", style)

		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color.WHITE
		hover_style.set_border_width_all(3)

		button.add_theme_stylebox_override("hover", hover_style)

		button.pressed.connect(
			_on_color_selected.bind(category, i)
		)

		grid.add_child(button)

func _populate_hat_grid() -> void:
	var hat_names := ["Default Hat", "Wizard Hat"]

	# Create buttons for each hat style.
	for i in range(gnome.hat_options.size()):
		var button := Button.new()

		button.custom_minimum_size = Vector2(100, 75)

		if i < hat_names.size():
			button.text = hat_names[i]
		else:
			button.text = "Hat %d" % i

		button.pressed.connect(
			_on_hat_style_selected.bind(i)
		)

		grid.add_child(button)
		
		button.toggle_mode = true
		button.button_pressed = (selected_customization["hat_style"] == i)

	if selected_customization["hat_style"] == 0:
		_populate_color_grid(Category.HAT)

func _populate_face_grid() -> void:
	for i in range(gnome.face_textures.size()):
		var button := Button.new()

		button.custom_minimum_size = Vector2(75, 75)
		button.icon = gnome.face_textures[i]
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		button.pressed.connect(
			_on_face_selected.bind(i)
		)

		grid.add_child(button)


func _on_face_selected(index: int) -> void:
	selected_customization["face"] = index
	gnome.set_face(index)


func _get_colors(category: int) -> Array[Color]:
	match category:
		Category.HAT:
			return ColorPalettes.HAT_COLORS
		Category.OUTFIT:
			return ColorPalettes.OUTFIT_COLORS
		Category.BEARD:
			return ColorPalettes.BEARD_COLORS

	return []


func _on_color_selected(category: int, index: int) -> void:
	var category_name := ""

	match category:
		Category.HAT:
			category_name = "hat"
		Category.OUTFIT:
			category_name = "outfit"
		Category.BEARD:
			category_name = "beard"

	var colors := _get_colors(category)
	var color: Color = colors[index]

	selected_customization[category_name] = index
	gnome.set_color(category_name, color)

func _on_hat_style_selected(index: int) -> void:
	selected_customization["hat_style"] = index
	gnome.set_hat_style(index)
	
	_populate_grid(Category.HAT)

func _on_done_pressed() -> void:
	print("Selected customization: ", selected_customization)
	HighLevelNetworkHandler.submit_customization(selected_customization)
	
	customization_finished.emit()
	hide()
