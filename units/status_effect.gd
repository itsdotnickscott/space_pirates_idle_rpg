class_name StatusEffect
extends Resource


export (Global.StatusType) var type
export var friendly: bool
export var turns: int

export (Global.ScaleType) var scale_type
export var scale_amount: float

export (Global.DamageType) var damage_type

# Flat values will be stored into this variable
export var flat_value: float = 0


func init(status_type: int, status_turns: int, scale: int, scale_amt: float, friend: bool = false, dmg_type: int = Global.DamageType.NONE) -> void:
	type = status_type
	turns = status_turns
	scale_type = scale
	scale_amount = scale_amt
	damage_type = dmg_type
	friendly = friend


func set_flat_value(val: float):
	flat_value = val