class_name Action
extends Resource


export (Global.ActionType) var type
export (Array, Global.Condition) var conditions
export (Global.TargetType) var target_type
export var friendly: bool = false

export (Global.ScaleType) var scale_type
export var scale_amount: float
export var scale_change: float = 1.0

export (Array, Resource) var apply
export (Global.DamageType) var damage_type
export var repeat: int
export var move_targ: int
export var move_self: int

export var animation: Animation
export var animation_name: String = "attack"