class_name BattleUI
extends Node2D


signal ability_selected(ability_type)
signal ability_hovered(ability_type)

# Health bar resources
var bar_red := preload("res://assets/battle/red_health_bar.png")
var bar_green := preload("res://assets/battle/green_health_bar.png")
var bar_yellow := preload("res://assets/battle/yellow_health_bar.png")

# Pip resources
var pip := preload("res://assets/battle/pip.png")
var empty_pip := preload("res://assets/battle/empty_pip.png")

# Icon resources
var ally_icon_bg := preload("res://assets/battle/ally_icon_bg.png")
var enemy_icon_bg := preload("res://assets/battle/enemy_icon_bg.png")

onready var ability_info_ui := preload("res://battle/AbilityInfoUI.tscn")

onready var ability_controls := $AbilityControls
onready var turn_order_bg := $TurnTrack/TurnOrderBackground
onready var turn_order := $TurnTrack/TurnOrder
onready var next_label := $TurnTrack/NextLabel
onready var curr_icon_bg := $CurrUnitInfo/CurrIconBackground
onready var curr_icon := $CurrUnitInfo/CurrIcon
onready var curr_name := $CurrUnitInfo/CurrName
onready var curr_pip_bar := $CurrUnitInfo/CurrPipBar
onready var curr_hp_label := $CurrUnitInfo/CurrHPLabel
onready var curr_hp_bar := $CurrUnitInfo/CurrHPBar
onready var curr_status_grid := $CurrUnitInfo/CurrStatusGrid


func _on_Ability_pressed(ability_type: int) -> void:
	emit_signal("ability_selected", ability_type)


func _on_Ability_mouse_entered(ability_type: int) -> void:
	emit_signal("ability_hovered", ability_type)


func _on_Ability_mouse_exited() -> void:
	for node in get_children():
		if node is AbilityInfoUI:
			node.queue_free()


func create_ability_info(ability: Ability, unit: Unit, ability_type: int) -> void:
	var info = ability_info_ui.instance()
	info.rect_global_position = ability_controls.get_children()[ability_type].rect_global_position
	add_child(info)
	info.init(ability, unit)
	

func update_turn_order(initiative: Array, curr_turn: int) -> void:
	reset_tracks()

	var turn_track = []

	for roll in initiative:
		if roll.unit != null:
			var icon := TextureRect.new()
			icon.texture = roll.unit.info.icon
			turn_track.append({"icon": icon, "team": roll.team})

	for i in range(turn_track.size() - 1, curr_turn, -1):
		turn_order.add_child(turn_track[i].icon)

		var bg := TextureRect.new()
		bg.texture = ally_icon_bg if turn_track[i].team == Global.Team.ALLY else enemy_icon_bg
		turn_order_bg.add_child(bg)

	if turn_order.get_children().size() == 0:
		next_label.visible = false
	else:
		next_label.visible = true


func reset_tracks() -> void:
	for icon in turn_order.get_children():
		turn_order.remove_child(icon)
		icon.queue_free()

	for bg in turn_order_bg.get_children():
		turn_order_bg.remove_child(bg)
		bg.queue_free()


func next_turn(unit: Unit, team: int) -> void:
	update_curr_unit(unit, team)
	update_curr_hp(unit)
	update_curr_pips(unit)
	update_curr_status_icons(unit)


func update_curr_unit(unit: Unit, team: int) -> void:
	curr_icon.texture = unit.info.icon
	curr_icon_bg.texture = ally_icon_bg if team == Global.Team.ALLY else enemy_icon_bg
	curr_name.text = unit.name


func update_curr_hp(unit: Unit) -> void:
	# HPLabel
	curr_hp_label.text = "%d/%d" % [unit.stats.curr_hp, unit.stats.max_hp]

	# HPBar
	curr_hp_bar.max_value = unit.stats.max_hp

	if unit.stats.curr_hp < unit.stats.max_hp * 0.34:
		curr_hp_bar.texture_progress = bar_red
	elif unit.stats.curr_hp < unit.stats.max_hp * 0.67:
		curr_hp_bar.texture_progress = bar_yellow
	else:
		curr_hp_bar.texture_progress = bar_green

	curr_hp_bar.value = unit.stats.curr_hp


func update_curr_pips(unit: Unit) -> void:
	var pip_sprites = curr_pip_bar.get_children()

	for i in range(pip_sprites.size()):
		if i < unit.stats.pips:
			pip_sprites[i].texture = pip
		else:
			pip_sprites[i].texture = empty_pip


func update_curr_status_icons(unit: Unit) -> void:
	# Remove all icons
	for icon in curr_status_grid.get_children():
		curr_status_grid.remove_child(icon)
		icon.queue_free()

	for status in unit.stats.status_effects:
		var src
		match status.type:
			Global.StatusType.BURN:
				src = preload("res://assets/status_effects/burn_status.png")
			Global.StatusType.WEAKEN:
				src = preload("res://assets/status_effects/weaken_status.png")
			Global.StatusType.STRENGTHEN:
				src = preload("res://assets/status_effects/strengthen_status.png")
			Global.StatusType.STUN:
				src = preload("res://assets/status_effects/stun_status.png")

		var icon = TextureRect.new()
		icon.texture = src
		curr_status_grid.add_child(icon)
