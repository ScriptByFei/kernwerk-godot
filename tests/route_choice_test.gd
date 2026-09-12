extends SceneTree

## Routenwahl: gelegentlich liegt neben der sicheren Route eine riskante
## Abzweigung. Geprueft wird, dass beide Wege fair erreichbar bleiben — ueber
## viele Seeds und Schwierigkeitsstufen, nicht an einem Gluecksfall.
##
## Wichtig: gemessen wird gegen den ROUTEN-VORGAENGER, nicht gegen den
## zufaellig vorherigen Eintrag. Eine Abzweigung haengt an der Hauptroute und
## darf nicht als eigenes Glied der Kette missverstanden werden. Ebenso gilt fuer
## jede Plattform das Schrittmass, das BEI IHRER ERZEUGUNG galt — sonst wuerde
## eine spaetere, strengere Stufe alte Plattformen faelschlich verurteilen.

const MIN_CENTER_DISTANCE := 240.0

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var risky_seen := 0
	var branches_seen := 0
	var worlds := 0
	for seed_value in range(24):
		var world := Node2D.new()
		root.add_child(world)
		var director := PlatformDirector.new(seed_value)
		director.initialize(world, JumpConfig.PLATFORM_LAYOUT)
		# Je Plattform: Position, Variante, Schwierigkeit bei der Erzeugung.
		var created := {}
		var order := []
		var known := {}
		var authored := {}
		for platform in director._active_platforms:
			# Die vorgegebenen Startledges sind gestaltete Startbedingungen, keine
			# generierte Route: ihre Abstaende waren nie an das Schrittmass
			# gebunden. Geprueft wird fuer sie nur, dass sie im Schacht liegen —
			# genau wie es die bestehende Director-Suite seit jeher handhabt.
			created[platform] = {"variant": platform.variant, "difficulty": 0, "position": platform.position, "authored": true}
			order.append(platform)
			known[platform] = true
			authored[platform] = true
		for step in range(60):
			var difficulty := step % (JumpConfig.MAX_DIFFICULTY + 1)
			director.maintain(-step * 420.0, -step * 420.0 + 1920.0, difficulty)
			for platform in director._active_platforms:
				if known.has(platform):
					continue
				known[platform] = true
				order.append(platform)
				created[platform] = {"variant": platform.variant, "difficulty": difficulty, "position": platform.position, "authored": false}
				if platform.variant == JumpPlatform.Variant.RISKY:
					risky_seen += 1
			_check(director.active_platform_count <= JumpConfig.MAX_ACTIVE_PLATFORMS, "Plattformzahl bleibt gedeckelt")
			worlds += 1
		# Auswertung: jede Plattform gegen ihren Routen-Vorgaenger.
		var route_predecessor := Vector2(INF, INF)
		var is_first := true
		for platform in order:
			var info: Dictionary = created[platform]
			var position: Vector2 = info["position"]
			_check(position.x - platform.platform_size.x * 0.5 >= -0.001 and position.x + platform.platform_size.x * 0.5 <= 1080.001, "Plattform bleibt im Schacht")
			if is_first:
				is_first = false
				route_predecessor = position
				continue
			var generated := not bool(info["authored"])
			var limit: float = _step_for(int(info["difficulty"]))
			var hop: float = absf(position.x - route_predecessor.x)
			if platform.variant == JumpPlatform.Variant.RISKY:
				branches_seen += 1
				_check(generated, "riskante Abzweigung stammt aus der Generierung")
			if generated:
				_check(hop <= limit + 0.001, "Seed %d: Sprung %.1f <= Schritt %.1f (Variante %d)" % [seed_value, hop, limit, platform.variant])
			# Die riskante Abzweigung selbst darf nicht zur Hauptroute werden:
			# nur die naechste regulaere Sprosse rueckt den Vorgaenger weiter.
			if platform.variant != JumpPlatform.Variant.RISKY:
				route_predecessor = position
		world.free()
	_check(risky_seen > 0, "riskante Plattformen entstehen ueberhaupt (%d)" % risky_seen)
	_check(branches_seen > 0, "Abzweigungen entstehen ueberhaupt (%d)" % branches_seen)
	_check(worlds > 0, "es wurde wirklich simuliert")
	# Eine riskante Landung zahlt genau einmal, danach nie wieder.
	var risky := JumpPlatform.new()
	risky.configure_variant(JumpPlatform.Variant.RISKY)
	var first := risky.claim_route_bonus()
	var second := risky.claim_route_bonus()
	_check(first == JumpConfig.RISKY_LANDING_BONUS and first > 0, "riskante Route zahlt die konfigurierte Belohnung")
	_check(second == 0, "dieselbe riskante Landung zahlt nicht erneut")
	# Die riskante Route ist schmaler und bietet dennoch die bessere Chance:
	# sichtbares Band und Klassifikation muessen dieselbe Breite nutzen.
	var standard := JumpPlatform.new()
	_check(risky.classify_contact(risky.resonance_band_width() * 0.5) == JumpConfig.LandingQuality.RESONANCE, "Rand des Risikobands zaehlt noch als RESONANCE")
	_check(risky.classify_contact(risky.resonance_band_width() * 0.5 + 0.5) == JumpConfig.LandingQuality.NORMAL, "knapp ausserhalb ist NORMAL")
	_check(risky.resonance_band_width() / risky.platform_size.x > standard.resonance_band_width() / standard.platform_size.x, "riskante Route hat die bessere Resonanzchance")
	_check(risky.classify_contact(JumpConfig.perfect_band_width(risky.platform_size.x) * 0.5) == JumpConfig.LandingQuality.PERFECT, "PERFECT bleibt auf der sichtbaren Zone")
	_check(risky.classify_contact(JumpConfig.perfect_band_width(risky.platform_size.x) * 0.5 + 0.5) == JumpConfig.LandingQuality.RESONANCE, "PERFECT-Zone waechst nicht mit")
	# Die bessere Chance darf keine garantierte sein: am Rand MUSS noch ein
	# echter NORMAL-Bereich liegen. Sonst koennte die riskante Route die Kette
	# nie verlieren, und "bessere Chance" waere in Wahrheit "kein Risiko".
	_check(risky.resonance_band_width() < risky.platform_size.x, "Resonanzband bleibt schmaler als die Plattform")
	_check((risky.platform_size.x - risky.resonance_band_width()) * 0.5 >= JumpConfig.RISKY_MIN_NORMAL_MARGIN, "es bleibt ein echter NORMAL-Rand je Seite")
	_check(standard.resonance_band_width() < standard.platform_size.x, "auch die sichere Route behaelt einen NORMAL-Bereich")
	_check(risky.classify_contact(risky.platform_size.x * 0.5 - 1.0) == JumpConfig.LandingQuality.NORMAL, "Rand der riskanten Route ist NORMAL")
	_check(risky.classify_contact(standard.platform_size.x * 0.5 - 1.0) == JumpConfig.LandingQuality.NORMAL, "Rand der sicheren Route ist NORMAL")
	_check(standard.claim_route_bonus() == 0, "sichere Route zahlt keinen Routenbonus")
	_check(JumpConfig.RISKY_LANDING_BONUS > 0, "Risiko wird ueberhaupt belohnt")
	risky.free()
	standard.free()
	_finish()

func _step_for(difficulty: int) -> float:
	return JumpConfig.PLATFORM_MAX_HORIZONTAL_STEP + clampi(difficulty, 0, JumpConfig.MAX_DIFFICULTY) * JumpConfig.DIFFICULTY_HORIZONTAL_BONUS

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures <= 20:
			print("FAIL: ", label)

func _finish() -> void:
	print("ROUTE CHOICE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
