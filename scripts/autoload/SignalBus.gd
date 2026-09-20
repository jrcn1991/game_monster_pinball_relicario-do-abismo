extends Node
## SignalBus: somente eventos realmente globais entre sistemas desacoplados.
## Regra: quem emite não conhece quem escuta. Nunca colocar lógica aqui.

# --- Partida / bolas ---
signal ball_served(ball: Node)
signal ball_drained(ball: Node, remaining_active: int)
signal ball_locked(locked_count: int)
signal multiball_started(ball_count: int)
signal multiball_ended()
signal ball_save_changed(active: bool, seconds_left: float)
signal tilt_warning(level: float)
signal tilt_triggered()
signal tilt_recovered()

# --- Combate ---
signal enemy_damaged(enemy: Node, amount: int, hit_position: Vector2, critical: bool)
signal enemy_died(enemy: Node, points: int, position: Vector2)
signal boss_phase_changed(phase: int)
signal boss_health_changed(current: int, maximum: int)
signal boss_awakened()
signal boss_defeated()
signal projectile_destroyed(position: Vector2)
signal ball_hit_by_projectile(ball: Node)

# --- Progressão / missão ---
signal seal_broken(seal_id: String, broken_count: int, total: int)
signal mission_portal_opened()
signal jackpot_collected(value: int)
signal bonus_sequence_started(seconds: float)
signal bonus_sequence_ended()

# --- Magia ---
signal mana_changed(current: int, maximum: int)
signal magic_activated(seconds: float)
signal magic_ended()

# --- Feedback / apresentação ---
signal impact(position: Vector2, intensity: float)  # intensity 0..1
signal request_screen_shake(strength: float)
signal request_flash(color: Color, strength: float)
signal hud_message(text: String, seconds: float)
signal target_hit(target_id: String, points: int, position: Vector2)
