class_name JumpConfig
extends RefCounted

## Physik. Gravitation und Absprungkraft werden seit dem Tempoumbau (15.09.2026)
## als PAAR gefuehrt: eine Stufe skaliert beide gemeinsam.
##
## Warum das Paar und nicht nur die Kraft: Der Scheitel ist v^2/(2g). Erhoeht man
## nur v, waechst der Sprung quadratisch — schneller hiesse dann auch hoeher und
## damit unfairer. Mit g -> k^2*g und v -> k*v bleibt der Scheitel EXAKT gleich
## und nur die Flugdauer sinkt (t ~ 1/k). Schneller ohne hoeher ist genau das.
##
## **Umstellung 20.09.2026: der ruhige Sprung ist WEICHER und LAENGER.** Timo
## wollte "mehr Tempo, aber nicht so starke Gravitation". Das sind zwei Hebel,
## und sie widersprechen sich, solange die Flugzeit (nicht der Scheitel) das
## Tempo traegt:
##
##   - Schneller im Sinne von kuerzerer Flugzeit geht NUR ueber hoehere
##     Gravitation (t = 2v/g) oder ueber eine kuerzere Strecke. Ein weicherer
##     Bogen ist zwangslaeufig ein laengerer Bogen.
##   - Tempo im Sinne von "kommt in Fahrt, baut auf" liegt deshalb NICHT hier,
##     sondern in den LADUNGEN: `RESONANCE_PACE_FACTORS` spreizt die Leiter, und
##     die Ladungen wachsen ueber einen geglueckten Lauf. Der Basiswert ist der
##     RUHEZUSTAND (0/3), nicht das Spieltempo.
##
## Gewaehlt: Gravitation -15 %, Kraft so bemessen, dass der Scheitel sinkt.
## Vorher 3887 / 2054 (Scheitel 526 px, Flug 0,98 s gemessen am echten Springer),
## jetzt 3304 / 1906 (Scheitel ~493 px, Flug ~1,08 s). Der Springer hat damit
## mehr Zeit im Bogen; die Landung bleibt ein sanfteres Abbremsen.
##
## Der Scheitel sinkt bewusst nur um ~6 %: er darf die weiteste Sprosse der
## schwersten Stufe (370 px) nicht unterschreiten, und ein zu hoher Sprung waere
## auf dem Telefon langsamer zu steuern. Als Test verankert, nicht nur hier
## kommentiert (siehe `gameplay_director_test`).
const GRAVITY := 3304.0
const BASE_BOUNCE_SPEED := 1906.0
# Third actual launch is perceptibly stronger than the second charged launch.
# Base bounce and charge multipliers stay unchanged; all launches remain capped.
const OVERLOAD_BOUNCE_SPEED := 4144.0
## Gravitation der Overload-Phase. Sie ist deutlich hoeher als jede normale
## Stufe, damit der laengere Flug trotzdem KUERZER dauert:
## gemessen 0,660 s gegen 0,717 s bei 2/3 und 0,856 s im Basissprung.
##
## Der alte Overload war 1,456 s lang und damit 27 % LANGSAMER als ein normaler
## Sprung — er belohnte den Spieler mit einem Gefuehl von Schwerfaelligkeit.
## Genau das war der Verstoss gegen "Overload darf den Spielfluss nicht
## verlangsamen". Die hoehere Gravitation ist der Hebel dagegen.
const OVERLOAD_GRAVITY := 11180.0
## Deckel aller Absprungkraefte. Er muss ueber dem groessten tatsaechlich
## erreichbaren Wert liegen, sonst flacht er die Tempoleiter ab, statt Unfaelle
## zu verhindern. Groesster erreichbarer Wert ist der Overload (4144) — der
## PERFECT-Boost greift dort nicht (siehe `pace_bounce`). Die alte Grenze 1960
## haette jede Overload gekappt.
const MAX_BOUNCE_SPEED := 4400.0
## Tempoleiter der Resonanzladungen, relativ zur Basisstufe (Index = Ladungen).
##
## 0/3 ist die ruhige Stufe, 2/3 die schnellste. Die Spreizung ist bewusst
## moderat: zwischen 0/3 und 2/3 liegen rund 25 % Flugdauer. Mehr waere auf dem
## Telefon nicht mehr steuerbar, weniger waere nicht spuerbar.
const RESONANCE_PACE_FACTORS := [0.88, 1.0, 1.16, 1.16]

## Tempo-Boost der PERFECT-Landung. Er gilt fuer GENAU DEN NAECHSTEN Absprung und
## ist danach verbraucht — kein Dauerzustand, kein Stapeln.
##
## Er wird wie die Tempoleiter ueber einen FAKTOR auf Kraft UND Gravitation
## gelegt (Kraft * k, Gravitation * k^2). Damit bleibt der Scheitel exakt gleich
## (v^2/(2g)) und nur die Flugzeit sinkt um ~1/k. Ein reiner Kraftaufschlag
## haette den Sprung hoeher gemacht — die Landung waere "schneller", aber auch
## weiter, und die Route nicht mehr dieselbe.
##
## 1.11 liegt in der geforderten Spanne 10-12 %: die Flugdauer sinkt um ~10 %.
const PERFECT_PACE_BOOST := 1.11

## Absprungkraft der aktuellen Stufe, einschliesslich Ladungsaufschlag und
## PERFECT-Boost.
##
## OVERLOAD IST VOM BOOST AUSGENOMMEN — bewusste Entscheidung, kein Versehen.
## Der Grund ist gerechnet, nicht geschaetzt: 4144 * 1.11 = 4600 liegt ueber
## MAX_BOUNCE_SPEED (4400). Die Kraft wuerde also gekappt, die Gravitation aber
## voll mit 1.11^2 skaliert. Der Scheitel faellt damit von 768 auf 703 px — die
## PERFECT-Landung wuerde den Overload um 8,5 % NIEDRIGER machen. Eine Belohnung,
## die den Sprung schlechter macht, ist keine.
##
## Der Spieler wird dabei nicht um seine Belohnung gebracht: der Overload selbst
## ist die Belohnung der PERFECT-Kette, und die Resonanzladung kommt unabhaengig
## davon in jedem Fall.
static func pace_bounce(charges: int, overload: bool, perfect_boost := false) -> float:
	if overload:
		return OVERLOAD_BOUNCE_SPEED
	var index := clampi(charges, 0, RESONANCE_PACE_FACTORS.size() - 1)
	var factor: float = RESONANCE_PACE_FACTORS[index] * (1.0 + resonance_bounce_bonus(charges))
	if perfect_boost:
		factor *= PERFECT_PACE_BOOST
	return BASE_BOUNCE_SPEED * factor

## Gravitation der aktuellen Stufe. Sie waechst mit dem QUADRAT des Faktors,
## damit der Scheitel konstant bleibt (siehe Kommentar bei GRAVITY).
##
## Der Ladungsaufschlag steckt BEIDSEITIG drin: erhoeht man nur die Kraft,
## waechst der Scheitel mit dem Quadrat des Aufschlags — 3/3 sprang dadurch 5,7 %
## hoeher als 2/3. Mit dem Aufschlag auch in der Gravitation ist der Scheitel
## ueber ALLE Stufen identisch und der Aufschlag wirkt als reine Temposteigerung.
## Dasselbe gilt fuer den PERFECT-Boost.
static func pace_gravity(charges: int, overload: bool, perfect_boost := false) -> float:
	if overload:
		return OVERLOAD_GRAVITY
	var index := clampi(charges, 0, RESONANCE_PACE_FACTORS.size() - 1)
	var factor: float = RESONANCE_PACE_FACTORS[index] * (1.0 + resonance_bounce_bonus(charges))
	if perfect_boost:
		factor *= PERFECT_PACE_BOOST
	return GRAVITY * factor * factor
## Dive: aktive Beeinflussung des Landungszeitpunkts.
##
## Einmal pro Sprung, nur in der FALLPHASE. Die Gravitation wird mit einem
## Faktor belegt (dieselbe Bauform wie die Tempoleiter, nur viel kraeftiger) und
## die Fallgeschwindigkeit gedeckelt, damit ein sehr spaeter Dive den Kern nicht
## in einem Tick durch eine Plattform traegt.
##
##   DIVE_GRAVITY_FACTOR 3.2  — spuerbar, aber kein Sturz
##   DIVE_MAX_FALL_SPEED 5200 — Deckel NUR im Dive
##   DIVE_MIN_FALL_SPEED  30  — der Kern muss wirklich fallen; im Scheitel waere
##                              der Dive nicht als Beschleunigung spuerbar und
##                              wuerde den Absprung beeinflussen
const DIVE_GRAVITY_FACTOR := 3.2
const DIVE_MAX_FALL_SPEED := 5200.0
const DIVE_MIN_FALL_SPEED := 30.0

## --- Dive-Rueckmeldung (Optik) ----------------------------------------------
## Der Dive war bis hierher nur an der Geschwindigkeit zu SPUEREN. Diese Werte
## geben ihm eine sichtbare Sprache, die zur bestehenden Formensprache passt:
## derselbe flache Ring am Fuesse-Punkt wie beim Kontakt, dazu eine nach oben
## ausduennende Schwanzspur als Richtungsanzeige ("es geht abwaerts").
##
## Alles wird in `_draw_contact_light` gezeichnet — kein zusaetzlicher Knoten,
## keine Textur, kein UI-Element. Farbe aus der bestehenden Palette.
const DIVE_FEEDBACK_COLOR := Color(1.0, 0.72, 0.34)
## Nach oben gezogene Aura: Grundradius und maximale Streckung.
##
## Die Werte sind am gerenderten Bild abgestimmt, nicht am Schreibtisch: der
## erste Versuch (Radius 70, Streckung 2,9, Deckkraft 0,30) ergab einen grossen
## braunen Fleck, der das Bild beherrschte und wie ein Renderfehler aussah
## (Begutachtung der Tafel, docs/assets/screenshots/dive_feedback/tafel.png).
## Der zweite Versuch (Radius 50, Streckung 2,1, Deckkraft 0,17) war zu leise:
## bei normaler Bildgroesse war kaum noch etwas zu sehen. Die Werte hier sind
## der mittlere Stand — deutlich sichtbar, ohne das Bild zu beherrschen. Etwas
## gesaettigtere Farbe, damit die Aura ueber dem dunklen Hintergrund nicht
## braun ausbleicht.
##
## Die Streckung waechst mit dem Tempo (`DIVE_GLOW_STRETCH` bei voller
## Fallgeschwindigkeit). Eine gezogene Flaeche hat keine Stabkante — im
## Unterschied zu duennen Linien, die am gerenderten Bild als Antenne gelesen
## wurden (siehe die gescheiterten Entwuerfe in docs/assets/screenshots/
## dive_feedback/).
const DIVE_GLOW_RADIUS := 56.0
const DIVE_GLOW_STRETCH := 2.5
const DIVE_GLOW_ALPHA := 0.24
## Ring am Fuesse-Punkt: Radius, Deckkraft und Strichstaerke.
const DIVE_RING_RADIUS := 62.0
const DIVE_RING_ALPHA := 0.85
const DIVE_RING_WIDTH := 3.0
## Weiche Aura um den Kern.
const DIVE_AURA_RADIUS := 96.0
const DIVE_AURA_ALPHA := 0.13
## Wisch-Erkennung. Alle drei Werte sind noetig; jeder schuetzt gegen eine andere
## Fehlausloesung (siehe `dive_input.gd`).
##
##   MIN_DISTANCE 80 DESIGN-Pixel — ein Zucken beim Umzielen ist kein Wisch.
##     ACHTUNG Koordinatenraum: `InputEvent.position` kommt in Design-Pixeln an
##     (Viewport 1080 breit), NICHT in Fensterpixeln. Auf einem 405 breiten
##     Fenster ist das der Faktor 2,667. Gemessen, nicht angenommen:
##     `qa/input_room_probe.gd`. Ein in Fensterpixeln gedachter Wert waere hier
##     um diesen Faktor zu klein und wuerde zu frueh ausloesen.
##   MAX_TIME 0.30 s — langsames Herunterziehen ist kein Wisch
##   DOMINANCE 1.6   — der WEG nach unten muss den Weg nach rechts deutlich
##                     uebersteigen. Es zaehlt der aufsummierte Weg, nicht die
##                     Verschiebung: sonst loest ein Umzielen mit
##                     Richtungswechsel aus (siehe `dive_input.gd`).
const DIVE_SWIPE_MIN_DISTANCE := 80.0
const DIVE_SWIPE_MAX_TIME := 0.30
const DIVE_SWIPE_DOMINANCE := 1.6

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
const LANDING_BOUNCE_MULTIPLIERS := [1.0, 1.025, 1.0]
## Warum PERFECT hier jetzt 1.0 ist (vorher 1.05):
##
## Der PERFECT-Vorteil ist von "etwas hoeher" auf "spuerbar schneller" umgestellt
## (PERFECT_PACE_BOOST, Kraft UND Gravitation gemeinsam). Beide zusammen waeren
## doppelt gezaehlt: 1,05 Kraft gegen 1,11^2 = 1,232 Gravitation waere immer noch
## ein hoeherer Scheitel — die perfekte Landung haette die Route veraendert,
## statt sie nur schneller zu machen. Die 5 % sind deshalb in den Boost
## uebergegangen, nicht zusaetzlich dazugekommen. RESONANCE behaelt seine 2,5 %:
## dort gibt es keinen Boost, die kleine Anhebung ist ihr ganzer Vorteil.
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
## Angebot der riskanten Abzweigung innerhalb einer Risk/Choice-Sequenz. Sie ist
## der Ort, an dem die Wahl PLANMAESSIG kommt: "Risk-Routen spaeter haeufiger
## anbieten" ist damit eine Eigenschaft der Form, nicht nur eine Zahl. Innerhalb
## der Sequenz ist das Angebot die Regel, nicht die Ausnahme — der Spieler soll
## die Wahl als Muster erkennen, nicht als Gluecksfall.
const RISKY_PATTERN_CHANCE := 0.75
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
## Daempfung der mittleren Schachtlinie. Sie laeuft hinter dem Spieler; in
## voller Staerke wirkt sie wie eine Fuehrungsschiene und markiert die
## Sprungbahn. 0.45 haelt sie als Gliederung lesbar, nimmt ihr aber die
## Dominanz (Astras Hinweis: "technische Hilfslinie").
const SHAFT_CENTER_DIM := 0.45
const ZONE_SHAFT_COLORS := [
	Color("20313b"),
	Color("244047"),
	Color("303d57"),
	Color("46394f"),
	Color("494343"),
]
## Hoehe jeder Zone in Weltpixeln (Zone 1 .. Zone 5).
##
## Am 17.09.2026 von 9000 je Zone auf diese Werte umgestellt (Timo). Grund:
## gemessen kommt ein idealisierter Ein-Daumen-Spieler auf rund 50 px/s. Mit
## 9000 px je Zone begann die Instabile Zone bei 22950 px — das sind etwa 7,6
## Minuten FEHLERFREIES Spiel, die Zonen 4 und 5 waren praktisch unerreichbar.
##
## Zone 1 bleibt bewusst GROESSER als die uebrigen. Der Reaktorschacht ist die
## praegendste und aufwendigste Zone, und seine Fernwand laeuft mit Parallax
## 0.22: im Fenster bis ZONE_FADE_START verschiebt sie sich nur um 0.22 * Hoehe.
## Gemessen zeigt ein 1650 px hohes Fenster nur 3 der 4 Modultypen (die Kacheln
## bleiben -2..1), ein 4400 px hohes Fenster alle 4. Eine gleichmaessige
## Stauchung haette also eine der vier gestalteten Wandarten aus Zone 1
## entfernt. Das ist der Grund fuer die ungleiche Aufteilung.
const ZONE_HEIGHT_SPANS := [8000.0, 4000.0, 4000.0, 4000.0, 4000.0]
## Nennhoehe der ERSTEN Zone. Nur noch fuer Rueckwaertsrechnungen und Proben, die
## eine grobe Schrittweite brauchen (z. B. "weit oberhalb" statt exakter Index).
## Die tatsaechliche Hoehe je Zone steht in ZONE_HEIGHT_SPANS.
const ZONE_HEIGHT_STEP := 8000.0
## Die gestalteten Schacht-Hintergruende gelten nur fuer die ersten beiden
## Stimmungen. Zone 1 (Reaktorschacht) laeuft bis 0.55 des Zonenindex und blendet
## dort aus; Zone 2 (Kuehlsektion) uebernimmt und blendet bis 1.55 aus. Oberhalb
## bleibt die reine Zonenfarbe — die hoeheren Zonen sind bewusst ungestaltet.
const SHAFT_ZONE_FADE_START := 0.55
const SHAFT_ZONE_FADE_END := 1.55
## Breite des weichen Uebergangs davor. Ohne diesen Verlauf waere der Wechsel
## eine sichtbare Stufe mitten im Flug.
##
## MUSS kleiner als die Zonenspanne bleiben: `zone_index_at` klemmt
## `blend = minf(ZONE_BLEND_RANGE, span)`. Bei blend >= span gaebe es kein
## Plateau mehr (siehe Kommentar an ZONE_HEIGHT_STEP). Am 17.09.2026 zusammen mit
## der Zonenhöhe von 3500 auf 1200 gestaucht, damit der Anteil gleich bleibt.
##
## Die Fenster der gestalteten Schichten liegen damit an den ZONENGRENZEN: der
## Index (i+1.0) faellt genau auf die Grenze zwischen Zone i und i+1, die
## Blendfenster enden also exakt dort. Das ist bewusst so und wurde nachgeprueft
## — ein laengerer Verlauf waere der falsche Hebel fuer den Zonenwechsel (Tim
## will einen ORT passieren, keinen langsameren Alpha-Verlauf). Dafuer sind die
## Uebergangsabschnitte der Facility-Struktur da
## (`ShaftBackground.draw_facility_transitions`).
const ZONE_BLEND_RANGE := 1200.0

## Untere Kante jeder Zone in Weltpixeln. Aus ZONE_HEIGHT_SPANS abgeleitet, damit
## beide Darstellungen niemals auseinanderlaufen koennen.
static func zone_floor(zone: int) -> float:
	var total := 0.0
	for i in range(clampi(zone, 0, ZONE_HEIGHT_SPANS.size())):
		total += ZONE_HEIGHT_SPANS[i]
	return total

## Gesamthoehe des gestalteten Schachts: dort ist der Index gedeckelt.
static func zone_total_height() -> float:
	return zone_floor(ZONE_HEIGHT_SPANS.size())

## Oberkante der Zone, in der diese Hoehe liegt, plus die Hoehe der Zone selbst.
static func zone_extent_at(height: float) -> Vector2:
	var climbed := maxf(0.0, height)
	var floor_y := 0.0
	for i in range(ZONE_HEIGHT_SPANS.size()):
		var span: float = ZONE_HEIGHT_SPANS[i]
		if climbed < floor_y + span or i == ZONE_HEIGHT_SPANS.size() - 1:
			return Vector2(floor_y, span)
		floor_y += span
	return Vector2(floor_y, ZONE_HEIGHT_SPANS[ZONE_HEIGHT_SPANS.size() - 1])

## Hoehe, an der ein gegebener Zonenindex erreicht wird. Die UMKEHRUNG von
## `zone_index_at` — Proben brauchen sie, um eine gewuenschte Zone exakt
## anzufahren, statt Pixelzahlen zu raten, die nur zufaellig stimmen.
##
## Achtung auf den Uebergangsbereich: ein ganzzahliger Index liegt genau an der
## Unterkante seiner Zone, ein gebrochener Teil t liegt `blend * t` darueber.
static func zone_height_for_index(index: float) -> float:
	var clamped := clampf(index, 0.0, float(ZONE_HEIGHT_SPANS.size() - 1))
	var base := int(floor(clamped))
	var frac := clamped - float(base)
	var floor_y := zone_floor(base)
	if frac <= 0.0:
		return floor_y
	var span: float = ZONE_HEIGHT_SPANS[clampi(base, 0, ZONE_HEIGHT_SPANS.size() - 1)]
	var blend := minf(ZONE_BLEND_RANGE, span)
	# Das Plateau laeuft bis `span - blend`, danach beginnt der Uebergang.
	return floor_y + (span - blend) + blend * frac

## Zonenindex als Fliesskommazahl: die Nachkommastellen beschreiben, wie weit
## der Uebergang zur naechsten Stimmung fortgeschritten ist.
##
## Die Zonen duerfen UNTERSCHIEDLICH hoch sein (ZONE_HEIGHT_SPANS). Deshalb wird
## die Zone erst per Schleife gesucht und dann INNERHALB ihrer eigenen Hoehe
## gerechnet — nicht mehr mit einer festen Schrittweite.
static func zone_index_at(height: float) -> float:
	var climbed := maxf(0.0, height)
	var count := ZONE_HEIGHT_SPANS.size()
	if count == 0:
		return 0.0
	# Kein separater Deckel-Check: die LETZTE Zone gibt weiter unten immer ihren
	# eigenen Index zurueck und bildet damit selbst den Deckel. Ein zusaetzlicher
	# Fruehausstieg war verhaltensneutral — die Mutationsprobe hat das entlarvt
	# (Mutation "Deckel verschoben" blieb gruen, weil sie nichts aendert).
	var floor_y := 0.0
	for i in range(count):
		var span: float = ZONE_HEIGHT_SPANS[i]
		if span <= 0.0:
			continue
		# Die LETZTE Zone hat keinen Nachfolger: in ihr gibt es keinen Uebergang.
		# Wird trotzdem einer gerechnet, liefert die Funktion Werte ueber dem
		# Deckel (gemessen 4.13 bei 22957 px) und faellt danach wieder auf 4.0
		# zurueck — der Index lief also rueckwaerts. Die letzte Zone bleibt
		# deshalb ueber ihre ganze Hoehe bei ihrem Index.
		if i == count - 1:
			return float(i)
		if climbed < floor_y + span:
			var within: float = climbed - floor_y
			var blend := minf(ZONE_BLEND_RANGE, span)
			if within <= span - blend:
				return float(i)
			return float(i) + (within - (span - blend)) / blend
		floor_y += span
	return float(count - 1)

## Mischfarbe der Zone fuer eine erreichte Hoehe.
##
## `zone_index_at` beschreibt bereits einen symmetrischen Verlauf um die
## Zonengrenze: bei 0.5 ist der Uebergang halb, bei 1.0 ist er ganz durch (die
## Zonengrenze liegt also in der Mitte der Rampe). Deshalb wird hier nur noch
## gelesen, was der Index sagt — keine zweite, abweichende Rampe darueber.
static func zone_color(palette: Array, height: float) -> Color:
	var index := zone_index_at(height)
	var lower := clampi(int(floor(index)), 0, palette.size() - 1)
	var upper := mini(lower + 1, palette.size() - 1)
	if upper == lower:
		return palette[lower] as Color
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

## Klangbett (Atmosphaere). Beide Schichten sind je 40 s lang und laufen als
## nahtlose Schleife; die Dateien entstehen aus `tools/make_ambience.py`. Damit
## sie sich nicht auseinanderziehen lassen, haben sie dieselbe Laenge.
const AMBIENCE_STREAM_PATH := "res://assets/jump/audio/shaft_ambience.ogg"
const AMBIENCE_TENSION_STREAM_PATH := "res://assets/jump/audio/shaft_tension.ogg"
const AMBIENCE_DB := -18.0
## Pegel, der als Aus bedeutet. AudioStreamPlayer kennt kein "aus": der leise
## Pegel ist der Schalter fuer die Spannungsschicht.
const AMBIENCE_SILENCE_DB := -80.0
## Pegel der Spannungsschicht bei Stufe 1 und bei MAX_DIFFICULTY.
##
## Der Hoechstpegel liegt UNTER dem Grundklang. Der erste Entwurf hatte -12.0 dB,
## also 6 dB ueber dem Bett — auf dem Telefon war das am Ende penetrant und zu
## laut (Timo, 14.09.). Der Grundklang bleibt das Fundament; die Spannung legt
## nur Dichte darauf, sie uebernimmt nicht das Feld.
const AMBIENCE_TENSION_LOW_DB := -28.0
const AMBIENCE_TENSION_DB := -23.0
## Dauer des Uebergangs, wenn die Schwierigkeit steigt. Ohne Ueberblendung
## springt die Atmosphaere bei jeder Stufe hoerbar um. Kurz gehalten: ein langer
## Aufbau klingt nach Absicht, wo nur ein Wechsel gemeint ist.
const AMBIENCE_TENSION_FADE := 1.5

## Pegel der Spannungsschicht zur Schwierigkeit. Stufe 0 ist Stille — die
## Atmosphaere soll wachsen, nicht von Anfang an da sein.
##
## Der Verlauf ist EASE-OUT, nicht linear: der groessere Teil des Anstiegs liegt
## frueh, danach bleibt es stabil. Linear baute sich der Klang ueber den GANZEN
## Lauf auf — am Ende klang das penetrant (Timo, 14.09.), weil es nie zur Ruhe
## kam. So ist nach der Haelfte der Strecke praktisch nichts mehr zu erwarten.
static func ambience_tension_db(difficulty: int) -> float:
	if difficulty <= 0:
		return AMBIENCE_SILENCE_DB
	var top := maxf(2.0, float(MAX_DIFFICULTY))
	var position := clampf(float(difficulty - 1) / (top - 1.0), 0.0, 1.0)
	var share := 1.0 - (1.0 - position) * (1.0 - position)
	return lerpf(AMBIENCE_TENSION_LOW_DB, AMBIENCE_TENSION_DB, share)

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
## Schwierigkeit haengt an der BEWAELTIGTEN HOEHE, nicht am Punktestand.
##
## Vorher lief sie ueber `score` und war bei Hoehe 5000 voll ausgeschoepft — nach
## rund 17 Sprossen passierte danach nichts mehr, der Rest des Runs war
## Wiederholung. Jetzt liegt die Hoechststufe bei Hoehe 8750, also nach etwa 29
## Sprossen, und bis dahin bewegt sich die Kurve weiter.
##
## Bewusst NICHT gekoppelt: die Atmosphaere. `AMBIENCE_TENSION_DB` beschreibt,
## wie laut die Spannungsschicht am ENDE des Laufs sein darf, und bleibt
## unveraendert — sonst wuerde dieselbe Anhebung den Klang nachjustieren, den
## Timo gerade abgenommen hat.
const DIFFICULTY_STEP_HEIGHT := 1250.0
const MAX_DIFFICULTY := 7
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

