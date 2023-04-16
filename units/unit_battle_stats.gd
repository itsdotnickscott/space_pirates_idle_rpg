class_name UnitBattleStats

extends Resource


# Unit info
var max_hp: float
var curr_hp: float
var pips: int

# Stats
var atk: float
var mag: float
var a_def: float
var m_def: float
var res: float

var acc: float
var dodge: float
var crit_rate: float
var crit_x: float
var spd: float

var status_effects: Array





func _init(unit_info: UnitInfo, _lvl: int, _items: Array) -> void:
	# TODO: Stats increase with level
	# TODO: Stats increase with items
	max_hp = unit_info.base_hp
	curr_hp = max_hp
	pips = 3 

	atk = unit_info.base_atk
	mag = unit_info.base_mag
	a_def = unit_info.base_a_def
	m_def = unit_info.base_m_def
	res = unit_info.base_res

	acc = unit_info.base_acc
	dodge = unit_info.base_dodge
	crit_rate = unit_info.base_crit_rate
	crit_x = unit_info.base_crit_x
	spd = unit_info.base_spd

	status_effects = []
