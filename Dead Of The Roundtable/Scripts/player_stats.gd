class_name PlayerStats
extends Resource

enum Stat {
	HEALTH, # flat value
	HEALTH_REGEN, # flat value
	THORNS, # flat value
	
	MOVEMENT_SPEED, # multiplier
	
	DAMAGE_MULTIPLIER, # multiplier
	RELOAD_SPEED_MULTIPLIER, # multiplier
	ATTACK_SPEED_MULTIPLIER, # multiplier
	
	CRITICAL_CHANCE_MULTIPLIER, # multiplier
	CRITICAL_DAMAGE_MULTIPLIER, # multiplier
	
	KNOCKBACK_MULTIPLIER, # multiplier
	
	ELEMENTAL_DAMAGE_MULTIPLIER, # multiplier
	ELEMENTAL_CHANCE_MULTIPLIER, # multiplier
}

signal stat_changed(stat: Stat, new_value: float)

@export var health: float:
	set(value):
		health = value
		stat_changed.emit(Stat.HEALTH, health)
		
@export var health_regen: float:
	set(value):
		health_regen = value
		stat_changed.emit(Stat.HEALTH_REGEN, health_regen)

@export var thorns: float:
	set(value):
		thorns = value
		stat_changed.emit(Stat.THORNS, thorns)
		
@export var movement_speed: float:
	set(value):
		movement_speed = 1.0 + value
		stat_changed.emit(Stat.MOVEMENT_SPEED, movement_speed)

@export var damage_multiplier: float:
	set(value):
		damage_multiplier = 1.0 + value
		stat_changed.emit(Stat.DAMAGE_MULTIPLIER, damage_multiplier)

@export var reload_speed_multiplier: float:
	set(value):
		reload_speed_multiplier = 1.0 + value
		stat_changed.emit(Stat.RELOAD_SPEED_MULTIPLIER, reload_speed_multiplier)

@export var attack_speed_multiplier: float:
	set(value):
		attack_speed_multiplier = 1.0 + value
		stat_changed.emit(Stat.ATTACK_SPEED_MULTIPLIER, attack_speed_multiplier)

@export var critical_chance_multiplier: float:
	set(value):
		critical_chance_multiplier = 1.0 + value
		stat_changed.emit(Stat.CRITICAL_CHANCE_MULTIPLIER, critical_chance_multiplier)

@export var critical_damage_multiplier: float:
	set(value):
		critical_damage_multiplier = 1.0 + value
		stat_changed.emit(Stat.CRITICAL_DAMAGE_MULTIPLIER, critical_damage_multiplier)

@export var knockback_multiplier: float:
	set(value):
		knockback_multiplier = 1.0 + value
		stat_changed.emit(Stat.KNOCKBACK_MULTIPLIER, knockback_multiplier)

@export var elemental_chance_multiplier: float:
	set(value):
		elemental_chance_multiplier = 1.0 + value
		stat_changed.emit(Stat.ELEMENTAL_CHANCE_MULTIPLIER, elemental_chance_multiplier)

@export var elemental_damage_multiplier: float:
	set(value):
		elemental_damage_multiplier = 1.0 + value
		stat_changed.emit(Stat.ELEMENTAL_DAMAGE_MULTIPLIER, elemental_damage_multiplier) 
