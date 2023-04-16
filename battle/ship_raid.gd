class_name ShipRaid
extends Node2D


enum Room {MAINTENANCE, MEDBAY, ARMORY, COCKPIT}
enum State {BATTLE, CHOOSE_ROOM}

onready var ship_ui: ShipUI = $ShipUI
onready var battle: Battle = $Battle

var ship: Array

var curr_stage: int = 0
var curr_room: int = 0
var raid_state: int


func generate_enemy_team() -> Array:
	return [
		{
			"unit_id": "fire_gunner_fox",
			"xp": 0,
			"items": [],
		},
		{
			"unit_id": "cow_dog",
			"xp": 0,
			"items": [],
		},
		{
			"unit_id": "fire_gunner_fox",
			"xp": 0,
			"items": [],
		},
		{
			"unit_id": "bard_snake",
			"xp": 0,
			"items": [],
		},
	]


func _ready() -> void:
	ship = [
		[ {"room": Room.MAINTENANCE, "id": 0, "button": $ShipUI/Room1} ],
		[ {"room": Room.MEDBAY, "id": 1, "button": $ShipUI/Room2}, {"room": Room.ARMORY, "id": 2, "button": $ShipUI/Room3} ],
		[ {"room": Room.COCKPIT, "id": 3, "button": $ShipUI/Room4} ],
	]

	# Connect children's signals
	var error_code = ship_ui.connect("room_pressed", self, "_on_Room_pressed")
	if error_code:
		print(error_code)

	error_code = battle.connect("team_dead", self, "_on_Battle_team_dead")
	if error_code:
		print(error_code)

	battle.start_stage(generate_enemy_team())
	raid_state = State.BATTLE
	

func _on_Battle_team_dead(team_num: int) -> void:
	if team_num == Global.Team.ENEMY:
		if curr_stage == ship.size() - 1:
			print("--------------------------------------")
			print("VICTORY")
			$Victory.visible = true
			return

		raid_state = State.CHOOSE_ROOM
		curr_stage += 1

		# Disable inaccessible rooms
		var i := 0
		for stage in ship:
			# Disable room if on a different stage
			var disable := false
			if i != curr_stage:
				disable = true

			for room in stage:
				room.button.disabled = disable

			i += 1

		ship_ui.visible = true

	else:
		print("--------------------------------------")
		print("DEFEAT")
		$Defeat.visible = true


func _on_Room_pressed(room: int) -> void:
		curr_room = room 
		ship_ui.visible = false
		battle.start_stage(generate_enemy_team())
