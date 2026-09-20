class_name Combat
## Regras de dano compartilhadas. Funções puras para facilitar testes.
## dano = dano_base × multiplicador_de_velocidade × bônus_de_combo × bônus_de_powerup

const BASE_DAMAGE := 1.0
const SLOW_SPEED := 300.0
const FAST_SPEED := 900.0
const INVULN_MS := 100  # invulnerabilidade por inimigo (80–120 ms)


## Retorna {"damage": int, "critical": bool, "tier": int} (tier 0 lento, 1 médio, 2 rápido).
static func damage_for_impact(impact_speed: float, consecrated: bool, combo_bonus: float) -> Dictionary:
	var tier := 0
	var speed_mult := 1.0
	if impact_speed >= FAST_SPEED:
		tier = 2
		speed_mult = 3.0
	elif impact_speed >= SLOW_SPEED:
		tier = 1
		speed_mult = 2.0
	var powerup_mult := 2.0 if consecrated else 1.0
	var dmg := int(round(BASE_DAMAGE * speed_mult * combo_bonus * powerup_mult))
	dmg = maxi(dmg, 1)
	return {"damage": dmg, "critical": tier == 2, "tier": tier}


## Intensidade de feedback 0..1 a partir da velocidade de impacto.
static func impact_intensity(impact_speed: float) -> float:
	return clampf(impact_speed / 1800.0, 0.05, 1.0)
