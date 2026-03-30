class_name PlayerStats
extends Resource

enum Stat {
	HEALTH,
	HEALTH_REGEN,
	THORNS,
	
	MOVEMENT_SPEED,
	
	DAMAGE_MULTIPLIER,
	RELOAD_SPEED_MULTIPLIER,
	ATTACK_SPEED_MULTIPLIER,
	
	CRITICAL_CHANCE_MULTIPLIER,
	CRITICAL_DAMAGE_MULTIPLIER,
	
	KNOCKBACK_MULTIPLIER,
	
	ELEMENTAL_DAMAGE_MULTIPLIER,
	ELEMENTAL_CHANCE_MULTIPLIER,
}

signal stat_changed(stat: Stat, new_value: float)

# Flat Stats
@export var health: float = 100.0:
	set(value):
		health = value
		stat_changed.emit(Stat.HEALTH, health)
		
@export var health_regen: float = 0.0:
	set(value):
		health_regen = value
		stat_changed.emit(Stat.HEALTH_REGEN, health_regen)

@export var thorns: float = 0.0:
	set(value):
		thorns = value
		stat_changed.emit(Stat.THORNS, thorns)

# Multipliers
@export var movement_speed: float = 1.0:
	set(value):
		movement_speed = value
		stat_changed.emit(Stat.MOVEMENT_SPEED, movement_speed)

@export var damage_multiplier: float = 1.0:
	set(value):
		damage_multiplier = value
		stat_changed.emit(Stat.DAMAGE_MULTIPLIER, damage_multiplier)

@export var reload_speed_multiplier: float = 1.0:
	set(value):
		reload_speed_multiplier = value
		stat_changed.emit(Stat.RELOAD_SPEED_MULTIPLIER, reload_speed_multiplier)

@export var attack_speed_multiplier: float = 1.0:
	set(value):
		attack_speed_multiplier = value
		stat_changed.emit(Stat.ATTACK_SPEED_MULTIPLIER, attack_speed_multiplier)

@export var critical_chance_multiplier: float = 1.0:
	set(value):
		critical_chance_multiplier = value
		stat_changed.emit(Stat.CRITICAL_CHANCE_MULTIPLIER, critical_chance_multiplier)

@export var critical_damage_multiplier: float = 1.0:
	set(value):
		critical_damage_multiplier = value
		stat_changed.emit(Stat.CRITICAL_DAMAGE_MULTIPLIER, critical_damage_multiplier)

@export var knockback_multiplier: float = 1.0:
	set(value):
		knockback_multiplier = value
		stat_changed.emit(Stat.KNOCKBACK_MULTIPLIER, knockback_multiplier)

@export var elemental_chance_multiplier: float = 1.0:
	set(value):
		elemental_chance_multiplier = value
		stat_changed.emit(Stat.ELEMENTAL_CHANCE_MULTIPLIER, elemental_chance_multiplier)

@export var elemental_damage_multiplier: float = 1.0:
	set(value):
		elemental_damage_multiplier = value
		stat_changed.emit(Stat.ELEMENTAL_DAMAGE_MULTIPLIER, elemental_damage_multiplier)

func apply_modifier(stat: Stat, amount: float) -> void:
	match stat:
		Stat.HEALTH: health += amount
		Stat.HEALTH_REGEN: health_regen += amount
		Stat.THORNS: thorns += amount
		
		Stat.MOVEMENT_SPEED: movement_speed += amount
		Stat.DAMAGE_MULTIPLIER: damage_multiplier += amount
		Stat.RELOAD_SPEED_MULTIPLIER: reload_speed_multiplier += amount
		Stat.ATTACK_SPEED_MULTIPLIER: attack_speed_multiplier += amount
		
		Stat.CRITICAL_CHANCE_MULTIPLIER: critical_chance_multiplier += amount
		Stat.CRITICAL_DAMAGE_MULTIPLIER: critical_damage_multiplier += amount
		
		Stat.KNOCKBACK_MULTIPLIER: knockback_multiplier += amount
		
		Stat.ELEMENTAL_CHANCE_MULTIPLIER: elemental_chance_multiplier += amount
		Stat.ELEMENTAL_DAMAGE_MULTIPLIER: elemental_damage_multiplier += amount
