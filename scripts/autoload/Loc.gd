extends Node
## Loc: textos em pt-BR preparados para localização.
## Uso: Loc.t("menu_play"). Chaves ausentes retornam a própria chave entre colchetes.

var _lang := "pt_BR"

var _strings := {
	"pt_BR": {
		"title": "RELICÁRIO DO ABISMO",
		"subtitle": "A bola é a arma",
		"menu_play": "JOGAR",
		"menu_options": "OPÇÕES",
		"menu_credits": "CRÉDITOS",
		"menu_quit": "SAIR",
		"menu_back": "VOLTAR",
		"menu_resume": "CONTINUAR",
		"menu_restart": "REINICIAR",
		"menu_to_menu": "MENU PRINCIPAL",
		"high_score": "RECORDE",
		"score": "PONTOS",
		"balls": "BOLAS",
		"multiplier": "MULT",
		"combo": "COMBO",
		"mana": "MANA",
		"boss": "BISPO SEM-ROSTO",
		"seals": "SELOS DO ABISMO",
		"seal_targets": "Alvos",
		"seal_guardian": "Guardião",
		"seal_runes": "Runas",
		"paused": "PAUSADO",
		"game_over": "FIM DE JOGO",
		"victory": "O ABISMO SE FECHA",
		"results": "RESULTADOS",
		"final_score": "Pontuação final",
		"new_record": "NOVO RECORDE!",
		"press_launch": "Segure ESPAÇO (ou o botão LANÇAR) para carregar, solte para lançar",
		"press_start": "Pressione ESPAÇO ou ENTER",
		"ball_saved": "BOLA SALVA",
		"ball_save_on": "SALVAMENTO ATIVO",
		"ball_lost": "BOLA PERDIDA",
		"tilt": "TILT!",
		"tilt_warning": "CUIDADO",
		"multiball": "MULTIBALL PROFANO",
		"ball_locked": "BOLA TRAVADA %d/2",
		"lock_ready": "TRAVA PRONTA",
		"magic_ready": "MAGIA PRONTA (SHIFT)",
		"magic_on": "BOLA CONSAGRADA",
		"drop_bank": "BANCO DE ALVOS COMPLETO",
		"lanes_complete": "ELOS COMPLETOS",
		"seal_broken": "SELO QUEBRADO: %s",
		"portal_open": "O BISPO SEM-ROSTO DESPERTOU",
		"boss_phase": "FASE %d",
		"boss_defeated": "BISPO DERROTADO  +25.000",
		"jackpot": "JACKPOT %s",
		"bonus_time": "SEQUÊNCIA BÔNUS",
		"guardian_shield_down": "ESCUDO DO GUARDIÃO QUEBRADO",
		"crit": "CRÍTICO",
		"opt_master": "Volume geral",
		"opt_music": "Música",
		"opt_sfx": "Efeitos",
		"opt_fullscreen": "Tela cheia",
		"opt_reduce_flash": "Reduzir flashes",
		"opt_reduce_shake": "Reduzir tremor",
		"opt_high_contrast": "Alto contraste",
		"on": "LIGADO",
		"off": "DESLIGADO",
		"controls_title": "CONTROLES",
		"controls_body": "A ou seta esquerda: flipper esquerdo    D ou seta direita: flipper direito\nESPAÇO  Lançar (segure p/ carregar)   SHIFT  Magia\nQ / E  Nudge (cuidado com o TILT)    ESC  Pausa    F3  Debug\nGamepad: LB/RB flippers, A lançar, X magia, D-pad nudge, Start pausa",
		"credits_body": "Relicário do Abismo — protótipo MVP\nDesign, código, arte provisória e áudio procedurais gerados para este projeto.\nMotor: Godot Engine 4 (licença MIT).\nVeja CREDITS.md e LICENSES/ para detalhes.",
		"seed": "Seed",
		"debug_hint": "F3: debug",
		"summon": "ESQUELETOS INVOCADOS",
		"eye_open": "O OLHO SE ABRE",
	}
}


func t(key: String) -> String:
	var table: Dictionary = _strings.get(_lang, {})
	if table.has(key):
		return table[key]
	return "[%s]" % key


func set_language(lang: String) -> void:
	if _strings.has(lang):
		_lang = lang
