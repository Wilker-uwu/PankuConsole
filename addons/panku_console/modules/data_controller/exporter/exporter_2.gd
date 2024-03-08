class_name MenuSettingsList extends VBoxContainer
## this file is a direct adaptation from PankuConsole hosted by Ark2000,
## which is distributed under the MIT License, and with many sections changed.
## the original code can be found at: https://github.com/Ark2000/PankuConsole/blob/master/addons/panku_console/modules/data_controller/exporter/exporter_2.gd

##i rewrote a bunch after midnight, and now i'm afraid of running it.
##will it work? will it break? will it be hours wasted for something that won't end up in the game?
##why tf did i stay awake for this?
##~wilker 

const BUTTON_PREFIX = "button__"
const COMMENT_PREFIX = "comment__"
const READONLY_PREFIX = "readonly__"
const TEXT_LABEL_MIN_X = 120

enum SettingType {READONLY, BUTTON_FUNC, BUTTON_GROUP, COMMENT, INTEGER, FLOAT, RANGE, VECTOR2, BOOLEAN, STRING, COLOR, ENUM}

var obj: Object

func _init(item_list: Object):
	obj = item_list

	assert(obj and is_instance_valid(obj))

	var row_types := []
	var rows := []

	var data = obj.get_property_list()
	for d in data:
		if d.name.begins_with("_"): continue
		if d.name.begins_with(READONLY_PREFIX):
			row_types.append(SettingType.READONLY)
			var row = MenuSettingString.new(obj, d)
			row.disabled = true
			rows.append(row)
			continue
		if d.usage == (PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE):
			match d.type:
				TYPE_STRING when d.name.begins_with(BUTTON_PREFIX):
					row_types.append(SettingType.BUTTON_FUNC)
					rows.append(MenuSettingButton.new(obj, d))
				TYPE_STRING when d.name.begins_with(COMMENT_PREFIX):
					row_types.append(SettingType.COMMENT)
					rows.append(MenuSettingComment.new(obj, d))
				TYPE_FLOAT,TYPE_INT when d.hint == PROPERTY_HINT_RANGE:
					row_types.append(SettingType.RANGE)
					rows.append(MenuSettingRange.new(obj, d))
				TYPE_BOOL:
					row_types.append(SettingType.BOOLEAN)
					rows.append(MenuSettingBool.new(obj, d))
				TYPE_STRING:
					row_types.append(SettingType.STRING)
					rows.append(MenuSettingString.new(obj, d))
				TYPE_COLOR:
					row_types.append(SettingType.COLOR)
					rows.append(MenuSettingColor.new(obj, d))
				TYPE_INT when d.hint == PROPERTY_HINT_ENUM:
					row_types.append(SettingType.ENUM)
					rows.append(MenuSettingEnum.new(obj, d))
				_:
					row_types.append(SettingType.READONLY)
					var row = MenuSettingString.new(obj, d)
					row.disabled = true
					rows.append(row)
		elif d.usage == PROPERTY_USAGE_GROUP:
			row_types.append(SettingType.BUTTON_GROUP)
			rows.append(MenuSettingGroup.new(d.name, []))

	var current_group_button = null
	var control_group = []
	for i in range(rows.size()):
		var row_type: SettingType = row_types[i]
		var row = rows[i]
		if row_type == SettingType.BUTTON_GROUP:
			if current_group_button != null:
				current_group_button.control_group = control_group
			control_group = []
			current_group_button = row
		else:
			if current_group_button != null:
				control_group.append(row)
	if control_group.size() > 0:
		current_group_button.control_group = control_group

	for row in rows:
		add_child(row)

	update_rows()

func is_empty() -> bool:
	return get_child_count() == 0

func update_rows():
	for row: MenuSettingRow in get_children():
		if not row.visible: continue
		row._downsync()

class MenuSettingRow extends HBoxContainer:
	var label: Label = Label.new()
	var control: Control
	var object: Object
	var property: Dictionary
	
	var disabled: bool: get = get_disabled, set = set_disabled
	
	signal setting_changed(value)

	func _init(obj: Object, prop: Dictionary):
		name = &"MenuSettingRow_%s" % prop
		object = obj
		property = prop
		label.name = prop.name
		label.text = prop.name.capitalize()
		label.custom_minimum_size.x = TEXT_LABEL_MIN_X

	func _enter_tree():
		add_child(label)
		add_child(control)
		control.size_flags_horizontal = Control.SIZE_EXPAND

	func _exit_tree(): for n in get_children(): n.free()

	func get_disabled() -> bool: return control.disabled
	func set_disabled(b: bool) -> void: control.disabled = b
	
	## Sends property data back to the object
	func _upsync(): assert(false, "This MenuSettingRow does not work with an usync implementation of its own. Use other node classes inheriting from MenuSettingRow instead.")
	## Picks up data from the object to update
	func _downsync(): assert(false, "This MenuSettingRow does not work with a downsync implementation of its own. Use other node classes inheriting from MenuSettingRow instead.")

class MenuSettingBool extends MenuSettingRow:
	func _init(obj: Object, prop: Dictionary):
		super(obj, prop)
		control = CheckBox.new()

	func _ready():
		control.toggled.connect(func(is_toggled_on):
			control.text = "Enabled" if is_toggled_on else "Disabled"
			setting_changed.emit(is_toggled_on)
		)

	func _upsync(): object[property.name] = control.button_pressed
	func _downsync(): control.button_pressed = object[property.name]

class MenuSettingColor extends MenuSettingRow:
	func _init(obj: Object, prop: Dictionary):
		super(obj, prop)
		control = create_picker()
	
	func _ready():
		control.color_changed.connect(func(color: Color):
			setting_changed.emit(color)
		)
	
	func _upsync(): object[property.name] = control.color
	func _downsync(): control.color = object[property.name]
	
	func create_picker() -> ColorPickerButton:
		var button = ColorPickerButton.new()
		var picker = button.get_picker()
		picker.can_add_swatches = false
		picker.color_mode = ColorPicker.MODE_OKHSL
		picker.picker_shape = ColorPicker.SHAPE_OKHSL_CIRCLE
		picker.color_modes_visible = false
		picker.presets_visible = false
		picker.sliders_visible = false
		return button

class MenuSettingRange extends MenuSettingRow:
	enum {SELECTION_NONE, SELECTION_ENUM, SELECTION_BOOL}
	const properties = {
		"or_greater": "allow_greater",
		"or_less": "allow_lesser",
		"exp": "exp_edit",
	#	"radians",
	#	"degrees",
	#	"hide_slider"
	}

	var _type := SELECTION_NONE
	
	func _init(obj: Object, prop: Dictionary):
		assert(property.type == TYPE_BOOL or property.type == TYPE_FLOAT)
		super(obj, prop)
		control = HSlider.new()

		var hint = property.hint_string.split(",", false)
		if hint.size() >= 2:
			control.min_value = float(hint[0])
			control.max_value = float(hint[1])
		
		for i in range(2, hint.size()):
			if i == 2 and !(hint[2] in properties):
				control.step = hint[2].to_float()
				continue
			if hint[i] in properties:
				control.set(properties[hint[i]], true)
		
		#set default step if not specified
		if hint.size() == 2:
			match property.type:
				TYPE_INT:
					control.step = 1
					control.rounded = true
				TYPE_FLOAT:
					control.step = (control.max_value - control.min_value) / 100.0
	
	func _ready():
		control.value_changed.connect(func(val):
			setting_changed.emit(val)
		)
	
	func _upsync(): object[property.name] = control.value
	func _downsync(): control.value = object[property.name]

class MenuSettingString extends MenuSettingRow:
	func _init(obj: Object, prop: Dictionary):
		super(obj, prop)
		control = TextEdit.new()
	
	func _ready():
		control.text_changed.connect(func():
			setting_changed.emit(control.text)
		)
	
	func _upsync(): object[property.name] = control.text
	func _downsync(): control.text = object[property.name]

class MenuSettingEnum extends MenuSettingRow:
	func _init(obj: Object, prop: Dictionary):
		var options: PackedStringArray = property.hint_string.split(",", false)
		assert(not options.is_empty(), "MenuSettingEnum requires at least one defined enum in its property flags.")
		super(obj, prop)
		control = OptionButton.new()
		for option in options:
			if option.begins_with("--"):
				control.add_separator(option.trim_prefix("--"))
			else:
				control.add_item(option)
	
	func _ready():
		control.item_selected.connect(func(index):
			setting_changed.emit(index)
		)
	
	func _upsync(): object[property.name] = control.get_selected_id()
	func _downsync(): (control as OptionButton).select(object[property.name])

class MenuSettingButton extends MenuSettingRow:
	func _init(obj: Object, prop: Dictionary):
		assert(obj.has_method(obj[property.name]), "Missing method implementation inside of object: %s.%s" % [property.name, obj[property.name]])
		super(obj, prop)
		label.text = property.name.trim_prefix(BUTTON_PREFIX).capitalize()
		control = Button.new()
		control.text = "Press"
	
	func _ready():
		control.pressed.connect(object.call.bind(object[property.name]))

class MenuSettingComment extends MenuSettingRow:
	func _init(obj: Object, prop: Dictionary):
		super(obj, prop)
		label.text = obj[property.name]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		control.free()

class MenuSettingGroup extends MenuSettingRow:
	const ICON = preload("res://assets/graphics/miscellaneous/icon.png")
	var control_group: Array[Control]
	var group_opened: bool: set = set_group_visibility

	func _init(title: StringName, group: Array[Control]):
		label.free()
		control = Button.new()
		control.icon = ICON
		control.text = title
		#control.flat = true
		control.expand_icon = true
		control.toggle_mode = true
		control.theme_type_variation = "MenuSettingsGroup"
		control_group = group

	func _ready():
		control.toggled.connect(set_group_visibility)
		set_group_visibility(false)
		control.button_pressed = false

	func set_group_visibility(enabled:bool):
		for node in control_group:
			node.visible = enabled

class Property:
	var name: String
	var a_class_name: StringName
	var type: Variant.Type
	var hint: PropertyHint
	var hint_string: String
	var usage: PropertyUsageFlags
