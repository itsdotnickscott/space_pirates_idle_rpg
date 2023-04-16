class_name Unit
extends Area2D


signal selected(unit)
signal death(unit)

signal dealt_dmg(target)
signal took_dmg()
signal heal_ally(target)
signal healed_hp()

signal pre_animation_completed()


# Health bar resources
var bar_red := preload("res://assets/battle/red_health_bar.png")
var bar_green := preload("res://assets/battle/green_health_bar.png")
var bar_yellow := preload("res://assets/battle/yellow_health_bar.png")

# Pip resources
var pip := preload("res://assets/battle/pip.png")
var empty_pip := preload("res://assets/battle/empty_pip.png")

# Value label resources
var ValueLabel := preload("res://units/ValueLabel.tscn")
var value_label_duration := 1.25

onready var battle_animation := $BattleAnimation
onready var sprite := $Sprite
onready var hp_bar := $UnitBattleUI/HPBar
onready var hp_label := $UnitBattleUI/HPLabel
onready var pip_bar := $UnitBattleUI/PipBar
onready var status_grid := $UnitBattleUI/StatusGrid
onready var turn_indicator := $UnitBattleUI/TurnIndicator

var info: UnitInfo
var stats: UnitBattleStats

var rng = RandomNumberGenerator.new()


func load_stats(unit: Dictionary, enemy: bool = false) -> void:
	if !Global.verify_Unit_Object(unit):
		print("error loading unit", unit)

	rng.randomize()

	# Load unit info and set stats
	info = load("res://units/unit_info/" + unit.unit_id + ".tres")
	stats = UnitBattleStats.new(info, calculate_lvl(unit.xp), unit.items)

	sprite.frames = info.sprite
	if enemy:
		sprite.set_flip_v(true)

	update_battle_ui()


func calculate_lvl(_xp: int) -> int:
	# TODO: Create xp/lvl curve
	return 1


func give_pip() -> void:
	if stats.pips != Global.MAX_PIPS:
		stats.pips += 1

	update_battle_ui()


func use_pips(cost: int) -> void:
	stats.pips -= cost
	update_battle_ui()


func take_dmg(unmitigated_dmg: float, dmg_type: int, crit: bool) -> float:
	var mitigated_dmg := 0.0

	# TODO: Element type weakness or strength

	# TODO: Shields soak up damage

	# Defense lowers damage based on damage type
	if dmg_type == Global.DamageType.ATTACK:
		mitigated_dmg += unmitigated_dmg * get_stat("a_def")
	elif dmg_type == Global.DamageType.MAGIC:
		mitigated_dmg += unmitigated_dmg * get_stat("m_def")

	var final_dmg = unmitigated_dmg - mitigated_dmg
	stats.curr_hp -= final_dmg

	var value_type
	match dmg_type:
		Global.DamageType.ATTACK:
			value_type = Global.ValueType.ATK_DMG
		Global.DamageType.MAGIC:
			value_type = Global.ValueType.MAG_DMG
		Global.DamageType.TRUE:
			value_type = Global.ValueType.TRUE_DMG

	show_value_label(String(floor(final_dmg)), value_type, crit, stats.max_hp)
	update_battle_ui()

	if final_dmg > 0:
		play_animation("take_dmg")
		emit_signal("took_dmg")

	return final_dmg


func deal_dmg(action: Action, target: Unit, crit: bool) -> float:
	var dmg := calculate_scaling_value(action.scale_type, action.scale_amount)

	# Check for damage multipliers
	for status in stats.status_effects:
		match status.type:
			Global.StatusType.WEAKEN, Global.StatusType.STRENGTHEN:
				if status.flat_value > 0:
					dmg += status.flat_value * (-1 if status.type == Global.StatusType.WEAKEN else 1)
				else:
					dmg += dmg * status.scale_amount * (-1 if status.type == Global.StatusType.WEAKEN else 1)

	# Crits increase damage
	if crit:
		dmg *= 1 + stats.crit_x

	# Every attack does 80% - 100% of base unmitigated damage
	dmg -= dmg * rng.randf_range(0, Global.VALUE_VARIANCE)

	if dmg > 0:
		emit_signal("dealt_dmg", target)

	return dmg


func heal_dmg(heal_val: float, crit: bool) -> float:
	var heal = heal_val

	# TODO: Heal multipliers

	stats.curr_hp = clamp(stats.curr_hp + heal, 0, stats.max_hp)

	show_value_label(String(floor(heal)), Global.ValueType.HEAL, crit, stats.max_hp)
	update_battle_ui()

	if heal > 0:
		play_animation("heal_dmg")
		emit_signal("healed_hp")

	return heal


func heal_ally(action: Action, target: Unit, crit: bool) -> float:
	var heal = calculate_scaling_value(action.scale_type, action.scale_amount)

	# TODO: Heal multipliers

	# Crits increase damage
	if crit:
		heal *= 1 + stats.crit_x

	# Heal variance
	heal -= heal * rng.randf_range(0, Global.VALUE_VARIANCE)

	if heal > 0:
		emit_signal("heal_ally", target)

	return heal


func apply_status(status: StatusEffect, applier: Unit) -> void:
	match status.type:
		Global.StatusType.BURN:
			if status.scale_type != Global.ScaleType.PCT_CURR_HP and status.scale_type != Global.ScaleType.PCT_MAX_HP:
				status.set_flat_value(applier.calculate_scaling_value(status.scale_type, status.scale_amount))

			print(name + " is burned!")

		Global.StatusType.WEAKEN, Global.StatusType.STRENGTHEN:
			if status.scale_type != Global.ScaleType.PCT_DMG:
				status.set_flat_value(applier.calculate_scaling_value(status.scale_type, status.scale_amount))

			print(name + " is " + ("weakened" if status.type == Global.StatusType.WEAKEN else "strengthened") + "!")

		Global.StatusType.STUN:
			print(name + " is stunned!")

	stats.status_effects.append(status)
	update_battle_ui()


func remove_status(idx: int) -> void:
	stats.status_effects.remove(idx)


func activate_statuses() -> void:
	for status in stats.status_effects:
		# If status has an effect on the start of turn, execute it
		match status.type:
			Global.StatusType.BURN:
				var dmg := 0.0

				if status.flat_value > 0:
					dmg = status.flat_value
				elif status.scale_type == Global.ScaleType.PCT_CURR_HP:
					dmg = status.scale_amount * stats.curr_hp
				elif status.scale_type == Global.ScaleType.PCT_MAX_HP:
					dmg = status.scale_amount * stats.max_hp

				var final_dmg = take_dmg(dmg, status.damage_type, false)
				print(name + " was burned for " + String(final_dmg) + " damage")

				if final_dmg > 0:
					play_animation("take_dmg")

			Global.StatusType.STUN:
				print(name + " is stunned, their turn is skipped")

		# Decrease turns left on status and remove if expired
		status.turns -= 1
		if status.turns <= 0:
			remove_status(stats.status_effects.find(status))
			continue

	update_battle_ui()


func can_take_turn() -> bool:
	if has_status(Global.StatusType.STUN):
		return false

	return true
			

func calculate_scaling_value(scale_type: int, scale_amt: float) -> float:
	var scale_stat: String
	match scale_type:
		Global.ScaleType.ATK:
			scale_stat = "atk"
		Global.ScaleType.MAG:
			scale_stat = "mag"
		Global.ScaleType.A_DEF:
			scale_stat = "a_def"
		Global.ScaleType.M_DEF:
			scale_stat = "m_def"
		Global.ScaleType.SPD:
			scale_stat = "spd"

	return scale_amt * get_stat(scale_stat)


func update_battle_ui() -> void:
	update_hp()
	update_pips()
	update_status_icons()


func update_hp() -> void:
	# HPLabel
	hp_label.text = String(ceil(stats.curr_hp)) + "HP"

	# HPBar
	hp_bar.max_value = stats.max_hp

	if stats.curr_hp < stats.max_hp * 0.34:
		hp_bar.texture_progress = bar_red
	elif stats.curr_hp < stats.max_hp * 0.67:
		hp_bar.texture_progress = bar_yellow
	else:
		hp_bar.texture_progress = bar_green

	hp_bar.value = stats.curr_hp


func update_pips() -> void:
	var pip_sprites = pip_bar.get_children()
	for i in range(pip_sprites.size()):
		if i < stats.pips:
			pip_sprites[i].texture = pip
		else:
			pip_sprites[i].texture = empty_pip


func update_status_icons() -> void:
	# Remove all icons
	for icon in status_grid.get_children():
		status_grid.remove_child(icon)
		icon.queue_free()

	for status in stats.status_effects:
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
		status_grid.add_child(icon)


func update_turn_indicator(vis: bool) -> void:
	turn_indicator.visible = vis


func get_stat(stat_name: String) -> float:
	return stats.get(stat_name)


func has_status(status_type: int) -> bool:
	for status in stats.status_effects:
		if status.type == status_type:
			return true

	return false


func show_value_label(value: String, type: int, crit: bool, max_val: float = 0):
	var value_label = ValueLabel.instance()
	add_child(value_label)
	value_label.show_value(value, value_label_duration, type, crit, max_val)


func play_animation(anim_name: String) -> void:
	if anim_name == "death":
		battle_animation.stop()
		battle_animation.clear_queue()
		battle_animation.play(anim_name)
		return

	battle_animation.queue(anim_name)


func add_animation(anim_name: String, anim: Animation) -> void:
	var error_code = battle_animation.add_animation(anim_name, anim)
	if error_code:
		print(error_code)


func _on_Unit_input_event(_viewport, event, _shapeidx) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT):
		emit_signal("selected", self)


func _on_Unit_pre_animation_completed() -> void:
	emit_signal("pre_animation_completed")


func _on_Unit_death() -> void:
	emit_signal("death", self)