class_name Ability
extends Resource

export var name: String
export var description: String

export (Array, Resource) var passive

export (Array, Resource) var sequence
export var pip_cost: int

export (Array, int) var req_position
export (Array, int) var target_positions
export (Global.Team) var target_team