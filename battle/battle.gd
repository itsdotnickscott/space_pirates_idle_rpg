class_name Battle
extends Node2D


signal action_complete()
signal team_dead(team)

enum GameState {CHOOSE_ABILITY, CHOOSE_TARGET, ANIMATION}
const POS_COORDS := [307, 242, 177, 112, 408, 473, 538, 603]
const FLOOR_COORD = 146

onready var unit_node = preload("res://units/Unit.tscn")
onready var battle_ui: BattleUI = $BattleUI

var rng = RandomNumberGenerator.new()

var teams: Array

var initiative: Array
var curr_round: int
var curr_turn: int
var game_state: int

var turn_log: Array

var ability_type: int
var target_unit: Unit
var kill_queue: Array = []


### -------------------- TURN SETUP FUNCTIONS -------------------- ###


func start_stage(enemies: Array) -> void:
	turn_log = []
	init_enemy_Units(enemies)
	curr_round = -1
	start_round()


func start_round() -> void:
	print("--------------------------------------")
	curr_round += 1
	turn_log.append([])
	roll_initiative()
	start_turn()


func end_turn() -> void:
	correct_positioning()

	# End battle if empty team
	if check_for_empty_team():
		return

	# Start a new round if all units have taken a turn
	if curr_turn >= initiative.size() - 1:
		start_round()
		return

	print("--------------------------------------")

	# Select unit for next turn
	curr_turn += 1
	start_turn()


func start_turn() -> void:
	battle_ui.update_turn_order(initiative, curr_turn)

	var curr_unit = get_curr_unit()

	if curr_unit == null:
		end_turn()
		return

	curr_unit.update_turn_indicator(true)
	curr_unit.give_pip()

	battle_ui.next_turn(curr_unit, get_team_num(curr_unit))
	
	if !curr_unit.can_take_turn():
		curr_unit.activate_statuses()
		curr_unit.update_turn_indicator(false)
		end_turn()
		return

	curr_unit.activate_statuses()

	activate_kill_queue()

	if kill_queue.size() > 0:
		return

	# Reset game state variables
	game_state = GameState.CHOOSE_ABILITY
	target_unit = null
	ability_type = 0

	# Enemy AI if enemy unit's turn
	if get_team_num(curr_unit) == Global.Team.ENEMY:
		enemy_turn()


func init_enemy_Units(enemies: Array) -> void:
	# Create Unit nodes and initialize them with their stats
	var i := 0
	for enemy in enemies:
		var unit = unit_node.instance()
		add_child(unit)
		unit.position = Vector2(POS_COORDS[i + 4], FLOOR_COORD)
		unit.name = "Enemy%s" % (i + 1)
		teams[Global.Team.ENEMY].append(unit)
		i += 1

	_connect_Unit_signals(enemies, true)


func roll_initiative() -> void:
	initiative = []

	# Roll initiatives for each unit
	var i := 0
	for team in teams:
		for unit in team:
			var roll = unit.get_stat("spd") + rng.randf_range(0, 8)
			initiative.append({"unit": unit, "roll": roll, "team": i})
		i += 1

	# Sort units by roll and reset turn number
	initiative.sort_custom(self, "sort_initiative")
	curr_turn = 0


func sort_initiative(a: Dictionary, b: Dictionary) -> bool:
	# Sort in descending order
	return true if a.roll > b.roll else false


func check_for_empty_team() -> bool:
	# Check for teams with no Units
	var i := 0
	for team in teams:
		if team.size() == 0:
			emit_signal("team_dead", i)
			return true
		i += 1

	return false


func enemy_turn() -> void:
	# Enemy AI simply attacks a random ally at the moment
	_on_Ability_selected(Global.AbilityType.ATTACK)
	_on_Unit_selected(teams[Global.Team.ALLY][rng.randi_range(0, teams[Global.Team.ALLY].size() - 1)])


### -------------------- PLAYER INPUT FUNCTIONS -------------------- ###


func _on_Ability_hovered(abil: int) -> void:
	if get_curr_unit():
		battle_ui.create_ability_info(get_curr_unit().info.ability_set[abil], get_curr_unit(), abil)


func _on_Ability_selected(abil: int) -> void:
	if game_state == GameState.CHOOSE_ABILITY or GameState.CHOOSE_TARGET:
		ability_type = abil
		game_state = GameState.CHOOSE_TARGET


func _on_Unit_selected(unit: Unit) -> void:
	if game_state == GameState.CHOOSE_TARGET:
		target_unit = unit
		validate_ability()


### -------------------- ABILITY VALIDATION FUNCTIONS -------------------- ###


func validate_ability() -> void:
	match ability_type:
		# Move left/right
		Global.AbilityType.MOVE_LEFT, Global.AbilityType.MOVE_RIGHT:
			var move = 1 if ability_type == Global.AbilityType.MOVE_LEFT else -1
			swap_positions(get_curr_unit(), move)
			get_curr_unit().update_turn_indicator(false)
			end_turn()
			return

		# Identify hero ability and check requirements
		_:
			var ability = get_curr_unit().info.ability_set[ability_type].duplicate()

			# Check that unit has enough pips
			if get_curr_unit().stats.pips - ability.pip_cost < 0:
				print("[err] Not enough pips")
				return

			# Check that target unit and required position is valid
			if !validate_position(ability):
				return

			# Execute ability if requirements are met
			execute_turn(ability)


func validate_position(ability: Ability) -> bool:
	# Check required position for unit
	if !validate_req_position(ability):
		print("[err] Cannot use ability from that position")
		return false

	# If enemy turn, target team should be switched
	var team = ability.target_team
	if get_team_num(get_curr_unit()) == Global.Team.ENEMY:
		team = Global.Team.ALLY if team == Global.Team.ENEMY else Global.Team.ENEMY

	# Check required position for target 
	if !validate_target_position(team, ability):
		print("[err] Invalid target")
		return false

	return true


func validate_req_position(ability: Ability) -> bool:
	# Check if current unit is in a valid position to use ability
	return ability.req_position.has(get_team(get_curr_unit()).find(get_curr_unit()))


func validate_target_position(team: int, ability: Ability) -> bool:
	# Check if target has to be in a specific team
	if team != Global.Team.ANY:
		# Check if target is in a valid team to use ability
		if !teams[team].has(target_unit):
			return false

	# Check if target is in a valid position
	return ability.target_positions.has(get_team(target_unit).find(target_unit))


### -------------------- EXECUTE FUNCTIONS -------------------- ###


func execute_turn(ability: Ability) -> void:
	turn_log[curr_round].append({
		"unit": get_curr_unit(),
		"ability": ability,
		"hit": false,
		"actions": [],
	})

	if hit_check():
		turn_log[curr_round][curr_turn].hit = true

		for action in ability.sequence:
			execute_action(action.duplicate(), ability)


func execute_action(action: Action, ability: Ability) -> void:
	var curr_log = turn_log[curr_round][curr_turn].actions

	curr_log.append({
		"action": action,
		"targets": [],
		"dodged": [],
		"values": [],
		"statuses": [],
		"resisted": [],
	})

	# Execute action more than once if ability repeats
	for _i in range(0, action.repeat + 1):
		var targets := determine_targets(action.target_type, ability.target_positions)

		curr_log.targets = targets

		for target in targets:
			if !action.friendly and dodge_check(target):
				curr_log.dodged.append(true)
				curr_log.values.append(0)
				curr_log.statuses.append([])
				curr_log.resisted.append([])
				continue

			curr_log.dodged.append(false)

			match action.type:
				Global.ActionType.DAMAGE, Global.ActionType.HEAL:
					curr_log.values.append(calculate_value(action, target))

				Global.ActionType.CONSUME_BURN:
					execute_consume_dot(action, target, Global.StatusType.BURN)

			for status in action.apply:
				execute_status(status, target)

			# Some action scale amount is affected after first cast
			action.scale_amount *= action.scale_change

			if action.move_targ != 0:
				swap_positions(target, action.move_targ)

	if action.move_self != 0:
		swap_positions(get_curr_unit(), action.move_self)

	correct_positioning()

	emit_signal("action_complete")


func calculate_value(action: Action, target: Unit) -> float:
	var curr_unit := get_curr_unit()
	var val := curr_unit.calculate_scaling_value(action.scale_type, action.scale_amount)
	
	# Check for value multiplier statuses
	if action.type == Global.ActionType.DAMAGE:
		for status in curr_unit.stats.status_effects:
			if status.type == Global.StatusType.WEAKEN or status.type == Global.StatusType.STRENGTHEN:
				# Weaken reduces damage while Strengthen increases damage
				var type := -1 if status.type == Global.StatusType.WEAKEN else 1
				if status.flat_value > 0:
					val += status.flat_value * type
				else:
					val += val * status.scale_amount * type

	var crit_roll := crit_check(curr_unit)
	if crit_roll:
		val *= 1 + curr_unit.stats.crit_x

	# Every value becomes 80% - 100% of its original value
	val -= val * rng.randf_range(0, Global.VALUE_VARIANCE)

	# If value type is damage, target will mitigate damage based on defense
	if action.type == Global.ActionType.DAMAGE:
		if action.damage_type == Global.DamageType.ATTACK:
			val -= target.get_stat("a_def")
		elif action.damage_type == Global.DamageType.MAGIC:
			val -= target.get_stat("m_def")

	return val


func calculate_consume_dot_dmg(action: Action, target: Unit, status: int) -> void:
	var total_dot_dmg := 0.0
	for effect in target.stats.status_effects:
		if effect.type == status:
			var dot_dmg := 0.0
			for _i in range(0, effect.turns):
				dot_dmg += get_curr_unit().calculate_scaling_value(effect.scale_type, effect.scale_amount)

			total_dot_dmg += target.take_dmg(dot_dmg, effect.damage_type, false)
			target.remove_status(target.stats.status_effects.find(effect))

	# Deal bonus damage, if applicable
	var crit_roll = crit_check(get_curr_unit())
	var unmitigated_dmg = get_curr_unit().deal_dmg(action, target, crit_roll)
	var final_dmg = target.take_dmg(unmitigated_dmg, action.damage_type, crit_roll)

	#if final_dmg + final_dot_dmg > 0:
		#print_battle_info("%s consumed DOTs and dealt %.2f damage to %s" % 
			#[get_curr_unit().name, final_dmg + final_dot_dmg, target.name])


func execute_ability(ability: Ability) -> void:
	# Accuracy check, if miss then end turn
	if !hit_check():
		target_unit.show_value_label("MISS!", Global.ValueType.MISS, false)
		get_curr_unit().update_turn_indicator(false)
		end_turn()
		return

	get_curr_unit().use_pips(ability.pip_cost)


func execute_damage(action: Action, target: Unit) -> void:
	var crit_roll = crit_check(get_curr_unit())
	var unmitigated_dmg = get_curr_unit().deal_dmg(action, target, crit_roll)
	var final_dmg = target.take_dmg(unmitigated_dmg, action.damage_type, crit_roll)

	if final_dmg > 0:
		print_battle_info("%s%s dealt %.2f damage to %s" % 
			[get_curr_unit().name, " crit and" if crit_roll else "", final_dmg, target.name])

		
func execute_heal(action: Action, target: Unit) -> void:
	var crit_roll = crit_check(get_curr_unit())
	var heal = get_curr_unit().heal_ally(action, target, crit_roll)
	var final_heal = target.heal_dmg(heal, crit_roll)

	if final_heal > 0:
		print_battle_info("%s%s healed %.2fHP to %s" % 
			[get_curr_unit().name, " crit and" if crit_roll else "", final_heal, target.name])


func execute_status(status: StatusEffect, target: Unit) -> void:
	# Resist check
	if !status.friendly and stat_roll(target, "res"):
		print(target.name + " resisted a status")
		target.show_value_label("RESIST!", Global.ValueType.RESIST, false)
		return

	target.apply_status(status, get_curr_unit())


func execute_consume_dot(action: Action, target: Unit, status: int) -> void:
	# Find every status that matches status type and deal damage based off of remaining turns
	var final_dot_dmg := 0.0
	for effect in target.stats.status_effects:
		if effect.type == status:
			var dot_dmg := 0.0
			for _i in range(0, effect.turns):
				dot_dmg += get_curr_unit().calculate_scaling_value(effect.scale_type, effect.scale_amount)

			final_dot_dmg += target.take_dmg(dot_dmg, effect.damage_type, false)
			target.remove_status(target.stats.status_effects.find(effect))

	# Deal bonus damage, if applicable
	var crit_roll = crit_check(get_curr_unit())
	var unmitigated_dmg = get_curr_unit().deal_dmg(action, target, crit_roll)
	var final_dmg = target.take_dmg(unmitigated_dmg, action.damage_type, crit_roll)

	if final_dmg + final_dot_dmg > 0:
		print_battle_info("%s consumed DOTs and dealt %.2f damage to %s" % 
			[get_curr_unit().name, final_dmg + final_dot_dmg, target.name])


### -------------------- BATTLE HELPER FUNCTIONS -------------------- ###


func determine_targets(target_type: int, target_positions: Array) -> Array:
	var targets := []

	# Determine targets based off of target type
	var target_team = get_team(target_unit)
	match target_type:
		Global.TargetType.SAME:
			targets.append(target_unit)

		Global.TargetType.SELF:
			targets.append(get_curr_unit())
			
		Global.TargetType.ALL:
			for pos in target_positions:
				targets.append(target_team[pos])

				if targets.size() == target_team.size():
					break

		Global.TargetType.RANDOM:
			var chosen := false
			while(!chosen):
				var roll = rng.randi_range(0, target_positions.size() - 1)

				if target_positions[roll] < target_team.size():
					targets.append(target_team[target_positions[roll]])
					chosen = true

		Global.TargetType.SPLASH:
			targets.append(target_unit)

			# Get left unit and right unit, if able
			var target_idx = target_team.find(target_unit)
			if target_idx - 1 >= 0:
				targets.append(target_team[target_idx - 1])

			if target_idx + 1 < target_team.size():
				targets.append(target_team[target_idx + 1])

		Global.TargetType.OTHER:
			var chosen := false

			# Choose a random unit other than the target
			if target_team.size() > 1:
				while(!chosen):
					var roll = rng.randi_range(0, target_positions.size() - 1)

					if target_positions[roll] < target_team.size():
						if roll != target_team.find(target_unit):
							targets.append(target_team[target_positions[roll]])
							chosen = true

	return targets


func correct_positioning() -> void:
	var i := 0
	for unit in teams[Global.Team.ALLY]:
		unit.position.x = POS_COORDS[i]
		i += 1

	i = 4
	for unit in teams[Global.Team.ENEMY]:
		unit.position.x = POS_COORDS[i]
		i += 1


func activate_kill_queue() -> void:
	# Kill units whose hp depleted
	for team in teams:
		for unit in team:
			if unit.stats.curr_hp <= 0:
				kill_queue.append(unit)
				unit.play_animation("death")


func _on_Unit_death(unit: Unit) -> void:
	for roll in initiative:
		if roll.unit == unit:
			roll.unit = null
			break
	
	get_team(unit).erase(unit)
	print(unit.name + " died!")
	kill_queue.erase(unit)
	unit.queue_free()

	if kill_queue.size() == 0:
		end_turn()


func swap_positions(unit: Unit, move: int) -> void:
	var team = get_team(unit)
	var idx = team.find(unit)
	if (idx + move >= 0) and (idx + move < team.size()):
		team[idx] = team[idx + move]
		team[idx + move] = unit


func stat_roll(unit: Unit, stat: String) -> bool:
	return unit.get_stat(stat) > rng.randf()


func hit_check() -> bool:
	if !stat_roll(get_curr_unit(), "acc"):
		print_battle_info(get_curr_unit().name + " missed!")
		return false
	return true


func dodge_check(unit: Unit) -> bool:
	if stat_roll(unit, "dodge"):
		print_battle_info(unit.name + " dodged " + get_curr_unit().name)
		unit.show_value_label("DODGE!", Global.ValueType.DODGE, false)
		return true
	return false


func crit_check(unit: Unit) -> bool:
	return stat_roll(unit, "crit_rate")


func get_curr_unit() -> Unit:
	if curr_turn >= initiative.size():
		return null

	return initiative[curr_turn].unit


func get_team(unit: Unit) -> Array:
	return teams[get_team_num(unit)]

			
func get_team_num(unit: Unit) -> int:
	return Global.Team.ALLY if teams[Global.Team.ALLY].has(unit) else Global.Team.ENEMY


func print_battle_info(info: String) -> void:
	print("[r%dt%d] %s" % [(curr_round + 1), (curr_turn + 1), info])


### -------------------- SETUP CONNECTION FUNCTIONS -------------------- ###


func _ready() -> void:
	rng.randomize()

	teams = [
		[$AllyUnit1, $AllyUnit2, $AllyUnit3, $AllyUnit4], 
		[]
	]

	_connect_BattleUI_signals()
	_connect_Unit_signals(Player.main_team)


func _connect_BattleUI_signals() -> void:
	var error_code = battle_ui.connect("ability_selected", self, "_on_Ability_selected")
	if error_code:
		print(error_code)

	error_code = battle_ui.connect("ability_hovered", self, "_on_Ability_hovered")
	if error_code:
		print(error_code)


func _connect_Unit_signals(team: Array, enemy: bool = false) -> void:
	var i = 0
	for unit in teams[Global.Team.ENEMY if enemy else Global.Team.ALLY]:
		# Init with unit id
		# TODO: Separate enemy team from ally units
		unit.load_stats(team[i])

		# Flip enemy sprites
		if enemy:
			unit.get_node("Sprite").set_flip_h(true)

		i += 1

		var signal_names = [
			["selected", "_on_Unit_selected"], 
			["death", "_on_Unit_death"], 
			#["pre_animation_completed", "execute_action"]
		]

		for s in signal_names:
			var error_code = unit.connect(s[0], self, s[1])
			if error_code:
				print(error_code)

		_establish_passives(unit)
		_load_action_animations(unit)


func _establish_passives(unit: Unit) -> void:
	for abil in unit.info.ability_set:
		for passive in abil.passive:
			if passive.signal_required:
				# Determine unit to attach signal to
				var attach: Unit
				match passive.attach_to:
					Global.TargetType.SELF:
						attach = unit

				# Attach signal
				var error_code = attach.connect(passive.signal_name, self, passive.call_fn_name)
				if error_code:
					print(error_code)


func _load_action_animations(unit: Unit) -> void:
	for abil in unit.info.ability_set:
		for action in abil.sequence:
			unit.add_animation(action.animation_name, action.animation)


### -------------------- PASSIVE ABILITY FUNCTIONS -------------------- ###


func _on_fire_gunner_fox_deal_dmg(target: Unit) -> void:
	yield(self, "action_complete")

	# Damaging a unit applies a Burn that deals (75% MAG) true damage over 3 turns.
	var status = StatusEffect.new()
	status.init(
		Global.StatusType.BURN, 
		3, 
		Global.ScaleType.MAG, 
		0.25, 
		false,
		Global.DamageType.TRUE
	)
	execute_status(status, target)


func _on_bard_snake_heal_ally(target: Unit) -> void:
	yield(self, "action_complete")

	# Healing an ally Strenghtens them for 2 turns, increasing their damage by 15%.
	var status = StatusEffect.new()
	status.init(
		Global.StatusType.STRENGTHEN,
		2,
		Global.ScaleType.PCT_DMG,
		0.15,
		true
	)
	execute_status(status, target)
