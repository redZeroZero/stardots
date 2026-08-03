class_name DataLinkProfile
extends Resource

@export_category("Capacités")
@export var can_receive: bool = true
@export var can_transmit: bool = true
@export var can_relay: bool = false
@export var provides_fire_control: bool = false
@export var can_bridge_groups: bool = false

@export_category("Portée et signature")
@export var transmission_range: float = 1200.0
@export var track_emission_strength: float = 0.20
@export var fire_control_emission_strength: float = 0.55
