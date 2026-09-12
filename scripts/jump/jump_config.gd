class_name JumpConfig
extends RefCounted

const GRAVITY := 2300.0
const BASE_BOUNCE_SPEED := 1580.0
# Third actual launch is perceptibly stronger than the second charged launch.
# Base bounce and charge multipliers stay unchanged; all launches remain capped.
const OVERLOAD_BOUNCE_SPEED := 1880.0
const MAX_BOUNCE_SPEED := 1960.0
const MAX_HORIZONTAL_SPEED := 1100.0
const HORIZONTAL_ACCELERATION := 10500.0
const HORIZONTAL_DRAG := 12000.0
const HORIZONTAL_TARGET_DISTANCE := 76.0
const HORIZONTAL_BRAKING := 15000.0
const HORIZONTAL_REVERSAL := 18000.0
const HORIZONTAL_TARGET_DEADZONE := 1.5
# Constant authority through the whole arc: no loss of late descent control.
# Braking caps target speed to stopping distance, without snapping position.

enum LandingQuality { NORMAL, RESONANCE, PERFECT }
# Ratios use FULL platform width, not half-width. Boundaries are inclusive.
# PERFECT 0.08 -> 0.15 -> 0.20: das urspruengliche Fenster war +-19 Welt-Pixel,
# auf einem 390pt-Telefon nur +-7 Punkte und damit unter der Daumen-Praezision.
# Jetzt +-48 px (+-17 Punkte); die sichtbare Sockelmarkierung zeichnet exakt
# dieselbe Breite (perfect_band_width), damit Ziel und Trefferzone gleich sind.
# RESONANCE bleibt bewusst schmaler als 2x PERFECT, damit aussen noch ein
# echter NORMAL-Bereich mit eigenem Impact-Feedback sichtbar bleibt.
const PERFECT_CENTER_RATIO := 0.24
const RESONANCE_CENTER_RATIO := 0.38
const LANDING_BOUNCE_MULTIPLIERS := [1.0, 1.025, 1.05]
# Resonanzladungen: die zentrale Kernmechanik. Jede RESONANCE- oder
# PERFECT-Landung laedt +1. Bei RESONANCE_MAX_CHARGES ist OVERLOAD scharf, der
# naechste Absprung nutzt OVERLOAD_BOUNCE_SPEED, danach steht die Resonanz
# wieder auf 0. Eine NORMAL-Landung loescht alle Ladungen.
const RESONANCE_MAX_CHARGES := 3
# Punkte je gehaltener Ladung. Index = Ladungsstand, 0 zahlt nichts.
const RESONANCE_SCORE_BY_CHARGE := [0, 5, 12, 25]
# Aufschlag auf die Absprungkraft je gehaltener Ladung. Wirkt auf den naechsten
# Absprung und bleibt unter MAX_BOUNCE_SPEED gedeckelt.
const RESONANCE_BOUNCE_BONUS_PER_CHARGE := 0.03
const RESONANCE_HUD_COLOR := Color(1.0, 0.73, 0.35)
const RESONANCE_HUD_DIM_COLOR := Color(0.30, 0.38, 0.44)
const RESONANCE_HUD_CHARGE_COLOR := Color(0.55, 0.95, 0.88)
const RESONANCE_OVERLOAD_COLOR := Color(1.0, 0.86, 0.42)
# Der Ring am Kontaktpunkt wird mit der Ladung heller, ohne zusaetzliche Objekte.
const RESONANCE_RING_CHARGE_GAIN := 1.0
# Dauerhafte Kernaufladung: der Ring um den Kern wird mit jeder Ladung groesser
# und heller. Am bereits gesaettigten Kern selbst waere eine reine Alpha-Erhoehung
# nicht messbar, deshalb waechst zusaetzlich der Radius nach aussen.
const CHARGE_LIGHT_RADIUS := [18.0, 22.0, 26.0]
const CHARGE_LIGHT_ALPHAS := [0.0, 0.10, 0.20]
# Overload waehrend des ueberladenen Flugs: warmgoldener Kernring plus Halo,
# gleiche Dauer wie die HUD-Anzeige, kein Vollkoerperflash.
const OVERLOAD_LIGHT_RADIUS := 30.0
const OVERLOAD_LIGHT_ALPHA := 0.35
## Die Wirkung gehoert NACH AUSSEN: das Reaktorbild ist rund 192 Weltpixel breit,
## ein Kernlicht darunter bleibt im gesaettigten Zentrum unsichtbar. Der
## warmgoldene Ring und die flache Aura liegen deshalb ausserhalb der Silhouette.
## Das Reaktorbild ist rund 192 Weltpixel breit; ein Ring darunter waere im
## Koerper versteckt. Beide Radien liegen deshalb ausserhalb der Silhouette und
## innerhalb der 280 breiten Plattform.
const OVERLOAD_RING_RADIUS := 120.0
const OVERLOAD_RING_WIDTH := 3.5
const OVERLOAD_RING_FLATTEN := 0.30
const OVERLOAD_AURA_RADIUS := 132.0
const OVERLOAD_AURA_ALPHA := 0.11
# Minimalistisches HUD: drei Segmente, kein Ziffern- oder Textzauber.
const RESONANCE_HUD_ORIGIN := Vector2(44.0, 72.0)
const RESONANCE_HUD_SEGMENT_SIZE := Vector2(44.0, 14.0)
const RESONANCE_HUD_SEGMENT_GAP := 9.0
# Abstand der Segmentzeile unter dem Score-Text.
const RESONANCE_HUD_ROW_OFFSET := 60.0
const RESONANCE_HUD_OUTLINE_WIDTH := 2.0
const RESONANCE_OVERLOAD_LABEL := "OVERLOAD"
# Das Spiel springt automatisch beim Landen ab. 3/3 existiert deshalb nur einen
# Physik-Tick lang und waere nie sichtbar (queue_redraw laeuft nach der Physik).
# Waehrend des ueberladenen Flugs bleibt die Anzeige stehen: dort ist der
# Overload tatsaechlich aktiv.
const RESONANCE_OVERLOAD_DISPLAY_TIME := 0.6
const LANDING_BONUSES_ENABLED := false
const LANDING_SCORE_BONUSES := [0, 1, 3]
const LANDING_EFFECT_DURATIONS := [0.12, 0.18, 0.22]
const LANDING_EFFECT_STRENGTHS := [0.12, 0.30, 0.46]
const LANDING_RING_RADII := [15.0, 40.0, 52.0]
const LANDING_RING_EXPANSION := 20.0
const LANDING_RING_FLATTEN := 0.25
const LANDING_RING_SEGMENTS := 24
const LANDING_RING_WIDTH := 2.5
const LANDING_GLOW_RADIUS := 50.0
const LANDING_GLOW_COLOR := Color(1.0, 0.54, 0.16)
const LANDING_CORE_LIGHT_COLOR := Color(1.0, 0.73, 0.35)
const LANDING_CORE_LIGHT_RADIUS := 16.0
const LANDING_CORE_LIGHT_GAIN := 0.35
const REACTOR_CORE_POSITION := Vector2(-1.0, -50.0)
const REACTOR_VISUAL_POSITION := Vector2(-96.0, -146.0)
const REACTOR_VISUAL_SCALE := Vector2(2.0, 2.0)
const LAND_ANIMATION_SPEED := 3.0
const JUMP_ANIMATION_SPEED := 1.0
## Routenwahl: gelegentlich liegt eine riskante Abzweigung neben der sicheren
## Route. Beide bleiben fair erreichbar; die riskante Route ist schmaler, gibt
## eine bessere Resonanzchance und zahlt eine einmalige, nicht farmbare Belohnung.
const RISKY_LANDING_BONUS := 25
const RISKY_LIFT := 150.0
const RISKY_CHANCE := 0.18
const RISKY_MIN_GAP_FACTOR := 0.80
## Resonanzband der riskanten Route relativ zur vollen Breite. Bessere Chance
## als die sichere Route (0.38), aber bewusst gedeckelt: auf einer 200 px breiten
## Schanze waere ein Band ab 0.5 breiter als die Plattform selbst. Dann waere
## JEDE Landung dort RESONANCE oder PERFECT, die riskante Route koennte die Kette
## nie verlieren — "bessere Chance" waere in Wahrheit "kein Risiko". Es bleibt
## deshalb ein echter NORMAL-Rand, und die PERFECT-Zone waechst nicht mit.
const RISKY_RESONANCE_RATIO := 0.42
## Mindestrand links und rechts, der auch auf der schmalen Route NORMAL bleibt.
const RISKY_MIN_NORMAL_MARGIN := 12.0

## Hoehenzonen: der Schacht wechselt mit steigender Hoehe weich zwischen fuenf
## Stimmungen. Nur Hintergrund und vorhandene Schachtlinien aendern sich;
## Plattformen, Kern und Trefferfarben bleiben konstant. Keine neuen Assets.
const ZONE_NAMES := ["Reaktorschacht", "Kuehlsektion", "Hochspannung", "Instabile Zone", "Kritische Zone"]
const ZONE_BACKGROUNDS := [
	Color("080d12"),
	Color("081416"),
	Color("101522"),
	Color("191321"),
	Color("1b1919"),
]
const ZONE_SHAFT_COLORS := [
	Color("20313b"),
	Color("244047"),
	Color("303d57"),
	Color("46394f"),
	Color("494343"),
]
## Hoehe in Weltpixeln, nach der die naechste Stimmung vollstaendig gilt.
const ZONE_HEIGHT_STEP := 9000.0
## Breite des weichen Uebergangs davor. Ohne diesen Verlauf waere der Wechsel
## eine sichtbare Stufe mitten im Flug.
const ZONE_BLEND_RANGE := 3500.0

## Zonenindex als Fliesskommazahl: die Nachkommastellen beschreiben, wie weit
## der Uebergang zur naechsten Stimmung fortgeschritten ist.
static func zone_index_at(height: float) -> float:
	var climbed := maxf(0.0, height)
	var step := ZONE_HEIGHT_STEP
	if step <= 0.0:
		return 0.0
	if climbed >= step * float(ZONE_BACKGROUNDS.size() - 1):
		return float(ZONE_BACKGROUNDS.size() - 1)
	var base: float = floor(climbed / step)
	var within: float = climbed - base * step
	var blend := minf(ZONE_BLEND_RANGE, step)
	if within <= step - blend:
		return base
	return base + (within - (step - blend)) / blend

## Mischfarbe der Zone fuer eine erreichte Hoehe.
static func zone_color(palette: Array, height: float) -> Color:
	var index := zone_index_at(height)
	var lower := clampi(int(floor(index)), 0, palette.size() - 1)
	var upper := mini(lower + 1, palette.size() - 1)
	return (palette[lower] as Color).lerp(palette[upper] as Color, clampf(index - float(lower), 0.0, 1.0))

const PLATFORM_BODY_COLOR := Color("233b46")
const PLATFORM_OUTLINE_COLOR := Color("10212a")
const PLATFORM_SHADOW_COLOR := Color("152630")
const PLATFORM_ENDCAP_COLOR := Color("314d58")
const PLATFORM_EDGE_COLOR := Color("69858d")
const PLATFORM_EDGE_HEIGHT := 5.0
const PLATFORM_SHADOW_HEIGHT := 7.0
const PLATFORM_ENDCAP_WIDTH := 14.0
const PLATFORM_OUTLINE_WIDTH := 2.0
const PLATFORM_CENTER_INSET_SIZE := Vector2(42.0, 14.0)
const PLATFORM_CENTER_INSET_COLOR := Color("10252d")
const PLATFORM_CENTER_MARK_SIZE := Vector2(28.0, 5.0)
const PLATFORM_CENTER_STEM_SIZE := Vector2(7.0, 9.0)
const PLATFORM_CENTER_MARK_COLOR := Color("4b9299")
const PLATFORM_IMPACT_DEPTH := [0.7, 1.5, 2.3]
const PLATFORM_IMPACT_COLORS := [Color("a0b8b8"), Color("72b9bc"), Color("ffd08a")]
const PLATFORM_IMPACT_ALPHAS := [0.65, 0.60, 0.75]
const PLATFORM_IMPACT_WIDTHS := [35.0, 70.0, 84.0]
const PERFECT_DASH_SIZE := Vector2(14.0, 7.0)
const PERFECT_DASH_TRAVEL := Vector2(21.0, 56.0)
const PERFECT_DASH_DURATION := 0.16
const PERFECT_DASH_COLOR := Color("e7b779")
const PERFECT_DASH_ALPHA := 0.65
const CAMERA_ASCENT_HEADROOM := 28.0
const CAMERA_HEADROOM_RESPONSE := 8.0
const CAMERA_APEX_SPEED := 180.0
const DEATH_DIM_DURATION := 0.18
const DEATH_DIM_COLOR := Color(0.20, 0.24, 0.26)
const LANDING_AUDIO_DB := [-24.0, -20.0, -14.0]
const DEATH_AUDIO_DB := -20.0

static func classify_landing(center_distance: float, full_width: float) -> LandingQuality:
	if full_width <= 0.0:
		return LandingQuality.NORMAL
	var distance := absf(center_distance)
	if distance <= full_width * PERFECT_CENTER_RATIO:
		return LandingQuality.PERFECT
	if distance <= full_width * RESONANCE_CENTER_RATIO:
		return LandingQuality.RESONANCE
	return LandingQuality.NORMAL

## Sichtbare Breite der PERFECT-Zone in Weltpixeln. Markierung und Trefferzone
## muessen dieselbe Quelle nutzen, sonst zielt der Spieler auf eine Flaeche,
## die nicht der Belohnung entspricht.
static func perfect_band_width(platform_width: float) -> float:
	return platform_width * PERFECT_CENTER_RATIO * 2.0

static func resonance_band_width(platform_width: float) -> float:
	return platform_width * RESONANCE_CENTER_RATIO * 2.0

## Kraftaufschlag des Resonanzstands auf den naechsten Absprung. Eine NORMAL-
## Landung traegt keine Ladung und damit keinen Aufschlag.
static func resonance_bounce_bonus(charges: int) -> float:
	return clampf(float(charges), 0.0, float(RESONANCE_MAX_CHARGES)) * RESONANCE_BOUNCE_BONUS_PER_CHARGE

## Gesamtbreite aller HUD-Segmente inklusive der Luecken dazwischen.
static func resonance_hud_width() -> float:
	var count := RESONANCE_MAX_CHARGES
	return count * RESONANCE_HUD_SEGMENT_SIZE.x + (count - 1) * RESONANCE_HUD_SEGMENT_GAP

const JUMPER_SIZE := Vector2(76.0, 76.0)
const PLATFORM_SIZE := Vector2(280.0, 40.0)
const PLATFORM_VERTICAL_GAP := 300.0
const PLATFORM_LOOKAHEAD := 1200.0
const PLATFORM_CLEANUP_MARGIN := 1200.0
const MAX_ACTIVE_PLATFORMS := 16
const PLATFORM_RUN_SEED := 13071337
const PLATFORM_MIN_CENTER_X := PLATFORM_SIZE.x * 0.5
const PLATFORM_MAX_CENTER_X := 1080.0 - PLATFORM_SIZE.x * 0.5
const PLATFORM_MAX_HORIZONTAL_STEP := 280.0
const CAMERA_LEAD := 260.0
const CAMERA_START := Vector2(540.0, 960.0)

# Gameplay-Loop
const SCORE_PER_UNIT := 10.0
const FALL_DEATH_MARGIN := 600.0
const DIFFICULTY_STEP_SCORE := 100.0
const MAX_DIFFICULTY := 5
const DIFFICULTY_VERTICAL_BONUS := 10.0
const DIFFICULTY_HORIZONTAL_BONUS := 20.0

const PLATFORM_LAYOUT: Array[Vector2] = [
	Vector2(540.0, 1760.0),
	Vector2(320.0, 1460.0),
	Vector2(620.0, 1160.0),
	Vector2(350.0, 860.0),
	Vector2(650.0, 560.0),
	Vector2(380.0, 260.0),
	Vector2(650.0, -40.0),
]

## Start transition choreography (seconds). Deterministic on process time via
## Tween, independent of refresh rate (30/60/120 FPS).
const START_TOTAL := 0.92
const START_PRESS_FEEDBACK := 0.12
const START_REVEAL_BEGIN := 0.28
const START_SECONDARY_BEGIN := 0.18
const START_SECONDARY_DURATION := 0.32
const START_TITLE_DURATION := 0.42
const START_CAMERA_DURATION := 0.60
const START_CAMERA_INTRO_OFFSET := 32.0
const START_BOUNCE_AT := START_TOTAL
## Subtle idle breathing for the menu, driven by Tween only.
const START_IDLE_PERIOD := 3.2
# Title glow: outline width as a fraction of the title font size, so the
# halo keeps its proportion on every screen size.
const START_TITLE_GLOW_RATIO := 0.055

## Pausenmenue. Zeiten in Sekunden, Flaechen in Design-Einheiten (1080 breit).
## Das Pausieren selbst setzt den SceneTree auf pause; der Ausblend-Tween laeuft
## deshalb mit TWEEN_PAUSE_PROCESS, sonst friert er in seinem ersten Bild ein und
## das Menue waere nie zu sehen.
const PAUSE_IN_DURATION := 0.12
const PAUSE_OUT_DURATION := 0.10
const PAUSE_TWEEN_PROCESS_MODE := Tween.TWEEN_PAUSE_PROCESS
const PAUSE_TITLE := "PAUSE"
const PAUSE_SCORE_LABEL := "SCORE"
const PAUSE_RESUME_LABEL := "WEITER"
const PAUSE_RESTART_LABEL := "NEU STARTEN"
const PAUSE_BUTTON_SIZE := Vector2(104.0, 104.0)
const PAUSE_BUTTON_MARGIN := 44.0
const PAUSE_BUTTON_BAR_SIZE := Vector2(9.0, 34.0)
const PAUSE_BUTTON_BAR_GAP := 12.0
## Trefferflaeche des Pausenknopfes. Bewusst groesser als die gezeichnete
## Flaeche: der Daumen trifft im Spiel, nicht am Schreibtisch.
const PAUSE_BUTTON_HIT_PADDING := 24.0
const PAUSE_DIM_COLOR := Color(0.02, 0.03, 0.05, 0.72)
const PAUSE_PANEL_COLOR := Color(0.055, 0.085, 0.10, 0.94)
const PAUSE_PANEL_BORDER_COLOR := Color(0.38, 0.47, 0.48, 0.80)
const PAUSE_TITLE_COLOR := Color(1.0, 0.965, 0.91)
const PAUSE_SCORE_COLOR := Color(0.72, 1.0, 0.92)
const PAUSE_SECONDARY_COLOR := Color(0.74, 0.80, 0.82)
const PAUSE_ROW_PLATE_COLOR := Color(0.055, 0.085, 0.10, 0.32)
const PAUSE_ROW_BORDER_COLOR := Color(0.38, 0.47, 0.48, 0.80)
const PAUSE_BUTTON_PLATE_COLOR := Color(0.055, 0.085, 0.10, 0.32)
const PAUSE_BUTTON_BORDER_COLOR := Color(0.38, 0.47, 0.48, 0.80)
## Warm wie der Titel des Startbildschirms: derselbe "unter Strom"-Ton.
const PAUSE_BUTTON_BAR_COLOR := Color(1.0, 0.86, 0.66)
## CanvasLayer des Pausenmenues. Ueber HUD (5) und Pausenknopf (89), unter dem
## Startmenue (10 ist dort ein eigener Layer, die Pause liegt bewusst darueber,
## weil sie nur waehrend PLAYING existiert).
const PAUSE_LAYER := 90

## Ergebnisanzeige nach dem Absturz.
##
## Der Lauf endet bewusst NICHT mehr von selbst: bei einem Endless-Spiel ist
## "wie hoch bin ich gekommen?" die zentrale Frage, und ein automatischer
## Neustart beantwortet sie nie — der erreichte Score wird im selben Moment von
## der neuen Runde ueberschrieben. Der Spieler entscheidet jetzt selbst.
const GAME_OVER_TITLE := "ABSTURZ"
const GAME_OVER_RESTART_LABEL := "NEU STARTEN"
const GAME_OVER_BEST_LABEL := "BESTWERT"
const GAME_OVER_RECORD_LABEL := "NEUER BESTWERT"
## Warm wie der Starttitel und die Overload-Anzeige: derselbe "unter Strom"-Ton.
const GAME_OVER_RECORD_COLOR := Color(1.0, 0.86, 0.66)
## Einblenddauer der Ergebnisanzeige. Sie stoppt den Baum nicht — die Welt ist
## ohnehin schon eingefroren — sondern blendet nur die Ueberlagerung ein.
const GAME_OVER_IN_DURATION := 0.22
## Kompakter Statistikblock der Ergebnisanzeige. Labels gedaempft, Zahlen hell;
## Warmgold fuer PERFECT/Overloads, Cyan fuer RESONANCE. Keine neue Aktion.
const GAME_OVER_HEIGHT_LABEL := "HOEHE"
const GAME_OVER_STAT_LABELS := ["PERFECT", "RESONANCE", "OVERLOAD", "BESTE KETTE"]
const GAME_OVER_STAT_COLORS := [
	Color(1.0, 0.86, 0.66),
	Color(0.55, 0.95, 0.88),
	Color(1.0, 0.86, 0.66),
	Color(0.74, 0.80, 0.82),
]
const GAME_OVER_CHAIN_LABEL := "BESTE KETTE"

