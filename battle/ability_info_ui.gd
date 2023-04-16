class_name AbilityInfoUI
extends Control


var valid_pos := preload("res://assets/battle/ability_info/valid_position.png")
var invalid_pos := preload("res://assets/battle/ability_info/invalid_position.png")
var ally_valid_pos := preload("res://assets/battle/ability_info/ally_valid_position.png")
var enemy_valid_pos := preload("res://assets/battle/ability_info/enemy_valid_position.png")

onready var req_position := $RequiredPosition
onready var target_position := $TargetPosition
onready var pip_cost := $PipCost
onready var abil_name := $Name
onready var description := $Description


func init(ability: Ability, unit: Unit) -> void:
	# Check required positions and set nodes
	var i := 3
	for icon in req_position.get_children():
		if ability.req_position.has(i):
			icon.texture = valid_pos
		i -= 1

	# Check target positions
	i = 0 if ability.target_team == Global.Team.ENEMY else 3
	for icon in target_position.get_children():
		if ability.target_positions.has(i):
			if ability.target_team == Global.Team.ENEMY:
				icon.texture = enemy_valid_pos
			else:
				icon.texture = ally_valid_pos
		
		i += 1 if ability.target_team == Global.Team.ENEMY else -1

	pip_cost.text = String(ability.pip_cost)
	#abil_name.text = ability.name
	description.bbcode_text = format_description(ability.description, unit)


func format_description(desc: String, unit: Unit) -> String:
	var desc_str := ""
	var val_str := ""
	for c in desc:
		# Record any values to be formatted
		if c == "(" or (val_str.length() > 0 and !(")" in val_str)):
			val_str += c
		else:
			desc_str += c

		# Format value if value string is complete
		if ")" in val_str:
			# Value string format: (val/stat/type)
			var start_val = val_str.find("(") + 1
			var end_val = val_str.find("/", start_val)
			var val = val_str.substr(start_val, end_val - start_val)

			var start_stat = end_val + 1
			var end_stat = val_str.find("/", start_stat)
			var stat = val_str.substr(start_stat, end_stat - start_stat)

			var start_type = end_stat + 1
			var end_type = val_str.find(")")
			var type = val_str.substr(start_type, end_type - start_type)

			# Calculate staling stat (val * stat)
			var calc_val := 0
			if val.is_valid_float():
				calc_val = int(float(val) * unit.get_stat(stat))

			# Determine color and ability type
			var color
			var abil_type
			match type:
				"atk":
					color = "ff9100"
					abil_type = "attack damage"
				"mag":
					color = "00ddff"
					abil_type = "magic damage"
				"true":
					color = "ffffff"
					abil_type = "true damage"
				"heal":
					color = "4dff00"
					abil_type = "HP"
				
			desc_str += "[color=#%s]%d-%d %s[/color]" % [color, calc_val - calc_val * Global.VALUE_VARIANCE, calc_val, abil_type]
			val_str = ""
	
	return desc_str
