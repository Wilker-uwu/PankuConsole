## Panku Console. Provide a runtime GDScript REPL so your can run any script expressions in your game!
##
## This class will be an autoload ([code] Console [/code] by default) if you enable the plugin. The basic idea is that you can run [Expression] based on an environment(or base instance) by [method execute]. You can view [code]default_env.gd[/code] to see how to prepare your own environment.
## [br]
## [br] What's more, you can...
## [br]
## [br] ● Send in-game notifications by [method notify]
## [br] ● Output something to the console window by [method output]
## [br] ● Manage widgets plans by [method add_widget], [method save_current_widgets_as], etc.
## [br] ● Lot's of useful expressions defined in [code]default_env.gd[/code].
##
## @tutorial:            https://github.com/Ark2000/PankuConsole
class_name PankuConsole extends CanvasLayer

## Emitted when the visibility (hidden/visible) of console window changes.
signal repl_visible_about_to_change(is_visible:bool)
signal repl_visible_changed(is_visible:bool)

#Static helper classes
const Config = preload("res://addons/panku_console/components/config.gd")
const Utils = preload("res://addons/panku_console/components/utils.gd")

#Other classes, define classes here instead of using keyword `class_name` so that the global namespace will not be affected.
const ExporterRowUI = preload("res://addons/panku_console/components/exporter/row_ui.gd")
const JoystickButton = preload("res://addons/panku_console/components/exporter/joystick_button.gd")
const LynxWindow = preload("res://addons/panku_console/components/lynx_window2/lynx_window.gd")
const Exporter = preload("res://addons/panku_console/components/exporter/exporter.gd")
const LynxWindow2 = preload("res://addons/panku_console/components/lynx_window2/lynx_window_2.gd")

const lynx_window_prefab = preload("res://addons/panku_console/components/lynx_window2/lynx_window_2.tscn")
const exp_key_mapper_prefab = preload("res://addons/panku_console/components/input_mapping/exp_key_mapper_2.tscn")
const monitoir_prefab = preload("res://addons/panku_console/components/monitor/monitor_2.tscn")
const exporter_prefab = preload("res://addons/panku_console/components/exporter/exporter_2.tscn")

## The input action used to toggle console. By default it is KEY_QUOTELEFT.
var toggle_console_action:String

## If [code]true[/code], pause the game when the console window is active.
var pause_when_active:bool

var init_expression:String = ""

var mini_repl_mode = false:
	set(v):
		mini_repl_mode = v
		if is_repl_window_opened:
			_mini_repl.visible = v
			_full_repl.visible = !v

var is_repl_window_opened := false:
	set(v):
		repl_visible_about_to_change.emit(v)
		await get_tree().process_frame
		is_repl_window_opened = v
		if mini_repl_mode:
			_mini_repl.visible = v
		else:
			_full_repl.visible = v
		if pause_when_active:
			get_tree().paused = v
			_full_repl._title_btn.text = "</> Panku REPL (Paused)"
		else:
			_full_repl._title_btn.text = "</> Panku REPL"
		repl_visible_changed.emit(v)

@export var _resident_logs:Node
@export var _base_instance:Node
@export var _mini_repl:Node
@export var _full_repl:Node
@export var godot_log_monitor:Node
@export var output_overlay:Node
@export var w_manager:Node
@export var options:Node

var _envs = {}
var _envs_info = {}
var _expression = Expression.new()

## Register an environment that run expressions.
## [br][code]env_name[/code]: the name of the environment
## [br][code]env[/code]: The base instance that runs the expressions. For exmaple your player node.
func register_env(env_name:String, env:Object):
	_envs[env_name] = env
	output("[color=green][Info][/color] [b]%s[/b] env loaded!"%env_name)
	if env is Node:
		env.tree_exiting.connect(
			func(): remove_env(env_name)
		)
	if env.get_script():
		var env_info = Utils.extract_info_from_script(env.get_script())
		for k in env_info:
			var keyword = "%s.%s" % [env_name, k]
			_envs_info[keyword] = env_info[k]

## Return the environment object or [code]null[/code] by its name.
func get_env(env_name:String) -> Node:
	return _envs.get(env_name)

## Remove the environment named [code]env_name[/code]
func remove_env(env_name:String):
	if _envs.has(env_name):
		_envs.erase(env_name)
		for k in _envs_info.keys():
			if k.begins_with(env_name + "."):
				_envs_info.erase(k)
	notify("[color=green][Info][/color] [b]%s[/b] env unloaded!"%env_name)

## Generate a notification
func notify(any) -> void:
	var text = str(any)
	_resident_logs.add_log(text)
	output(text)

func output(any) -> void:
	_full_repl.get_content().output(any)

#Execute an expression in a preset environment.
func execute(exp:String) -> Dictionary:
	return Utils.execute_exp(exp, _expression, _base_instance, _envs)

func get_available_export_objs() -> Array:
	var result = []
	for obj_name in _envs:
		var obj = _envs[obj_name]
		if !obj.get_script():
			continue
		var export_properties = Utils.get_export_properties_from_script(obj.get_script())
		if export_properties.is_empty():
			continue
		result.push_back(obj_name)
	return result

func add_exporter_window(obj:Object, window_title := ""):
	if !obj.get_script():
		return

	var new_window:LynxWindow2 = lynx_window_prefab.instantiate()
	if window_title == "":
		new_window._title_btn.text = "Exporter (%s)" % str(obj)
	else:
		new_window._title_btn.text = window_title
	new_window.window_closed.connect(new_window.queue_free)
	new_window._options_btn.hide()
	w_manager.add_child(new_window)
	var content = exporter_prefab.instantiate()
	new_window.set_content(content)
	content.setup(obj)
	new_window.centered()

func add_exp_key_mapper_window():
	var new_window:LynxWindow2 = lynx_window_prefab.instantiate()
	new_window._title_btn.text = "Expression Key Mapper"
	new_window.window_closed.connect(new_window.queue_free)
	new_window._options_btn.hide()
	w_manager.add_child(new_window)
	new_window.set_content(exp_key_mapper_prefab.instantiate())
	new_window.centered()

func add_monitor_window(exp:String, update_period:= 999999.0, position:Vector2 = Vector2(0, 0), size:Vector2 = Vector2(160, 60), title_text := ""):
	var new_window:LynxWindow2 = lynx_window_prefab.instantiate()
	if title_text == "": title_text = exp
	new_window._title_btn.text = title_text
	new_window.window_closed.connect(new_window.queue_free)
	var content = monitoir_prefab.instantiate()
	content.update_exp = exp
	content.update_period = update_period
	new_window._options_btn.pressed.connect(content.toggle_settings)
	new_window._title_btn.pressed.connect(content.update_exp_i)
	w_manager.add_child(new_window)
	new_window.set_content(content)
	new_window.position = position
	new_window.size = size
	return new_window

func show_intro():
	output("[center][b][color=#f5891d][ Panku Console ][/color][/b] [color=#f5f5f5][b]Version 1.2.32[/b][/color][/center]")
	output("[center][img=96]res://addons/panku_console/logo.svg[/img][/center]")
	output("[color=#f5f5f5][b]Check [color=#f5891d]repl_console_env.gd[/color] or simply type [color=#f5891d]help[/color] to see what you can do now![/b][/color] [color=#f5f5f5][b]For more information, please visit: [color=#f5891d][url=https://github.com/Ark2000/PankuConsole]project github page[/url][/color][/b][/color].")
	output("")

func _input(_e):
	if Input.is_action_just_pressed(toggle_console_action):
		is_repl_window_opened = !is_repl_window_opened

func _ready():
	assert(get_tree().current_scene != self, "Do not run this directly")

	show_intro()
	toggle_console_action = ProjectSettings.get("panku/toggle_console_action")
	
#	print(Config.get_config())
	_full_repl.hide()
	_mini_repl.hide()
	
	_full_repl._options_btn.pressed.connect(
		func():
			add_exporter_window(options, "Panku Settings")
	)
	
	_full_repl.window_closed.connect(
		func():
			is_repl_window_opened = false
	)

	#check the action key
	#the open console action can be change in the export options of panku.tscn
	assert(InputMap.has_action(toggle_console_action), "Please specify an action to open the console!")

	#add info of base instance
	var env_info = Utils.extract_info_from_script(_base_instance.get_script())
	for k in env_info: _envs_info[k] = env_info[k]
	
	#load configs
	var cfg = Config.get_config()

	if cfg.has("widgets_data"):
		var w_data = cfg["widgets_data"]
		for w in w_data:
			add_monitor_window(w["exp"], w["period"], w["position"], w["size"], w["title"])
		cfg["widgets_data"] = []
	
	await get_tree().process_frame
	
	if cfg.has("init_exp"):
		var init_exp = cfg["init_exp"]
		for e in init_exp:
			execute(e)
		cfg["init_exp"] = []

	await get_tree().process_frame

	if cfg.has("repl"):
		is_repl_window_opened = cfg.repl.visible
		_full_repl.position = cfg.repl.position
		_full_repl.size = cfg.repl.size
		
	if cfg.has("mini_repl"):
		mini_repl_mode = cfg.mini_repl

	Config.set_config(cfg)

#	register_env("panku", self)

func _notification(what):
	#quit event
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var cfg = Config.get_config()
		if !cfg.has("repl"):
			cfg["repl"] = {
				"visible":false,
				"position":Vector2(0, 0),
				"size":Vector2(200, 200)
			}
		cfg.repl.visible = is_repl_window_opened
		cfg.repl.position = _full_repl.position
		cfg.repl.size = _full_repl.size
		if !cfg.has("mini_repl"):
			cfg["mini_repl"] = false
		cfg.mini_repl = mini_repl_mode
		Config.set_config(cfg)
