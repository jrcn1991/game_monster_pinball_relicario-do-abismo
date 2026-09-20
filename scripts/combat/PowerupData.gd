class_name PowerupData
extends Resource
## Dados de power-ups. Arquitetura preparada; apenas "Bola Consagrada" é implementada no MVP.

@export var id: String = "consecrated_ball"
@export var display_name: String = "Bola Consagrada"
@export var mana_cost: int = 100
@export var duration: float = 8.0
@export var damage_multiplier: float = 2.0
@export var implemented: bool = true
