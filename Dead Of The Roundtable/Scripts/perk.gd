extends Resource
class_name Perk

@export var perk_name: String = "Base Perk"
@export var perk_desc: String = ""

# Standard Hooks
func on_tick(player: Node3D, delta: float) -> void: pass
func on_equip(player: Node3D) -> void: pass
func on_unequip(player: Node3D) -> void: pass

# Combat Hooks
func modify_hit(context: HitContext) -> void: pass
func modify_incoming_hit(context: HitContext) -> void: pass
func on_kill(context: HitContext) -> void: pass

# Spell Hooks
func on_cast(player: Node3D) -> void: pass
func on_recharge(player: Node3D) -> void: pass
