extends Node


enum AbilityType {
	NOT_SELECTED,
	ATTACK,
	PRIMARY,
	SECONDARY,
	ULTIMATE,
	MOVE_LEFT,
	MOVE_RIGHT,
}

enum ActionType {
	DAMAGE,
	HEAL,
	SHIELD,
	APPLY,
	MOVE,
	CONSUME_BURN,
}

enum Condition {
	LAST_ACTION_SUCCESSFUL,
	HAS_BURN,
}

enum ElementType {
	FIRE,
	LIFE,
}

enum DamageType {
	NONE,
	ATTACK,
	MAGIC,
	TRUE,
}

enum ScaleType {
	NONE,
	ATK,
	MAG,
	A_DEF,
	M_DEF,
	SPD,
	PCT_DMG,
	PCT_CURR_HP,
	PCT_MAX_HP,
}

enum StatusType {
	BURN,
	WEAKEN,
	STRENGTHEN,
	STUN,
}

enum TargetType {
	SAME,
	SELF,
	ALL,
	RANDOM,
	SPLASH,
	OTHER,
}

enum Team {
	ALLY,
	ENEMY,
	ANY,
}

enum ValueType {
	ATK_DMG,
	MAG_DMG,
	TRUE_DMG,
	HEAL,
	SHIELD_DMG,
	MISS,
	DODGE,
	RESIST,
}

const MAX_PIPS := 3
const VALUE_VARIANCE := 0.25


func verify_Unit_Object(unit: Dictionary) -> bool:
	return unit.has_all(["unit_id", "xp", "items"])