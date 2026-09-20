class_name EnemyData
extends Resource
## Dados configuráveis de inimigos (Resource). Editáveis em data/enemies/*.tres.

@export var display_name: String = "Inimigo"
@export var max_hp: int = 3
@export var points_on_death: int = 1000
@export var points_on_hit: int = 100
@export var mana_on_hit: int = 2
@export var mana_on_death: int = 0
@export var respawn_seconds: float = 12.0
@export var invulnerability_ms: int = 100
