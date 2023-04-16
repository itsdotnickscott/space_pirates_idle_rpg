class_name ValueLabel
extends Node2D


var rng = RandomNumberGenerator.new()

var mass = 200
var velocity
var gravity = Vector2(0, 1)


func show_value(value: String, duration: int, type: int, crit: bool, max_val: float) -> void:
	rng.randomize()

	velocity = Vector2(rng.randf_range(25, 75), rng.randf_range(-125, -75))

	z_index = 1
	$Value.text = value

	$Tween.interpolate_property(self, "modulate:a",
		1.0, 0.0, duration,
		Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, 0.5)

	# Change color value type
	match type:
		Global.ValueType.ATK_DMG:
			modulate = Color("ff9100")
		Global.ValueType.MAG_DMG:
			modulate = Color("00ddff")
		Global.ValueType.TRUE_DMG:
			modulate = Color("ffffff")
		Global.ValueType.HEAL:
			modulate = Color("4dff00")
		Global.ValueType.SHIELD_DMG:
			modulate = Color("c9c9c9")
		_:
			modulate = Color("d10e00")

	if crit:
		$Crit.visible = true

	if max_val > 0:
		scale *= clamp(float(value) / max_val + 0.7, 0.7, 2)

	# Start animation and wait to finish
	$Tween.start()
	yield($Tween, "tween_all_completed")
	queue_free()


func _process(delta) -> void:
	velocity += gravity * mass * delta
	position += velocity * delta