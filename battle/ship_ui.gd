class_name ShipUI
extends Node2D


signal room_pressed(room)


func _on_Room_pressed(room: int):
	emit_signal("room_pressed", room)