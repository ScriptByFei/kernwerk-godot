extends SceneTree
## Phase-4-Tests: GameManager-Logik + PlayerHealth + Game-Over-Verhalten.
## Aufruf: godot4 --headless -s tests/phase4_test.gd

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ " + msg)
	else:
		fails += 1
		print("  ✗ " + msg)

func _init() -> void:
	var world := Node2D.new()
	get_root().add_child(world)

	# --- GameManager Basis ---
	var gm := GameManager.new()
	world.add_child(gm)
	_check(gm.state == GameManager.State.START, "Initialzustand START")
	gm.start_run()
	_check(gm.is_running(), "Start-Zustand RUNNING")
	_check(gm.score == 0 and gm.kills == 0, "Score/Kills starten bei 0")

	var score_events := [0]
	gm.score_changed.connect(func(_s): score_events[0] += 1)
	gm.add_score(25)
	_check(gm.score == 25 and score_events[0] == 1, "add_score erhöht + Signal")
	gm.add_kill()
	_check(gm.kills == 1 and gm.score == 35, "add_kill: kills++ und +10 Score")

	# --- GameManager: Game Over ---
	var over_events := [0]
	gm.game_over.connect(func(): over_events[0] += 1)
	gm.damage_player(200)  # lethal
	_check(gm.state == GameManager.State.GAME_OVER, "Lethal → GAME_OVER")
	_check(over_events[0] == 1, "game_over genau 1×")
	# Nach Game Over: keine Punkte/Schaden mehr
	gm.add_score(999)
	gm.add_kill()
	_check(gm.score == 35 and gm.kills == 1, "Nach Game Over: keine Score-/Kill-Änderung")

	# --- GameManager reset ---
	gm.reset()
	_check(gm.is_running(), "reset → RUNNING")
	_check(gm.score == 0 and gm.kills == 0, "reset → Score/Kills 0")

	# --- PlayerHealth: Damage + iFrames ---
	var ph := PlayerHealth.new()
	world.add_child(ph)
	ph.setup(gm)
	_check(ph.hp == GameConfig.MAX_HEALTH, "Start-HP MAX")
	ph.take_hit(30)
	_check(ph.hp == GameConfig.MAX_HEALTH - 30, "take_hit 30 → HP-30")
	ph.take_hit(30)
	_check(ph.hp == GameConfig.MAX_HEALTH - 30, "iFrames: 2. Hit direkt danach wirkungslos")

	# --- PlayerHealth: Tod ---
	var died := [0]
	ph.player_died.connect(func(): died[0] += 1)
	gm.player_hp = 10
	ph.iframes_hard_clear()
	ph.take_hit(20)
	_check(died[0] == 1, "HP 0 → player_died 1×")

	# --- PlayerHealth reset ---
	gm.reset()
	ph.reset()
	_check(ph.hp == GameConfig.MAX_HEALTH and not ph._game_over, "reset → volle HP, lebendig")

	# --- Enemy-Kill verdrahtet Score (Game-Logik als reine Funktion getestet) ---
	# Score für Kill: +10 (wie in GameManager.add_kill). Nach reset: 1 Kill (+10), jetzt der 2.
	gm.add_kill()
	_check(gm.score == 10 and gm.kills == 1, "Kill → +10 Score (nach reset)")

	if fails == 0:
		print("PHASE4 TESTS: ALLE OK")
	else:
		print("PHASE4 TESTS: %d FEHLER" % fails)
	quit(1 if fails > 0 else 0)
