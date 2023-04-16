class_name UnitInfo
extends Resource


# Unit information
export var id: String
export var sprite: SpriteFrames
export var icon: Texture

export (Global.ElementType) var element_type
export (Array, Resource) var ability_set

# Base stats
export var base_hp: float = 10

export var base_atk: float = 5
export var base_mag: float = 5
export var base_a_def: float = 0.05
export var base_m_def: float = 0.05
export var base_res: float = 0.05

export var base_acc: float = 0.9
export var base_dodge: float = 0.05
export var base_crit_rate: float = 0.05
export var base_crit_x: float = 0.5
export var base_spd: float = 5

# Growth stats
export var hp_growth: float

export var atk_growth: float
export var mag_growth: float
export var a_def_growth: float
export var m_def_growth: float
export var res_growth: float

export var acc_growth: float
export var dodge_growth: float
export var crit_rate_growth: float
export var crit_x_growth: float
export var spd_growth: float