## Board topology: the single source of truth for every cell on the Ludo board.
##
## Mirrors src/game/layout.js of the Three.js prototype, so both builds agree.
## Grid: 15 x 15 cells, Vector2i(column, row), row 0 at the top.
##
## Progress per token:
##   0          in the home yard (base)
##   1 .. 51    common ring, starting at the colour's start square
##   52 .. 56   the five cells of the colour's home column
##   57         finished (centre)
class_name BoardPath
extends RefCounted

const GRID_SIZE := 15
const RING_LENGTH := 52
const COMMON_STEPS := 51
const LANE_STEPS := 5
const FINISH_PROGRESS := 57
const TOKENS_PER_PLAYER := 4
## Turn order is clockwise on screen.
## Clockwise seat order on the supplied board: blue (top-left), yellow (top-right),
## green (bottom-right), red (bottom-left).
const COLORS: Array[String] = ["blue", "yellow", "green", "red"]

## World size of one cell, measured from the supplied board model: the
## 15 x 15 playfield (ivory tiles) is about 10.98 m wide.
const CELL_SIZE := 10.98 / 15.0

## The drawn board is stretched along X so it can fill a wide phone screen. The grid is unchanged.
const BOARD_ASPECT_X := 1.6

## Per-colour data, matching the supplied board model.
## entry = ring index of the outer end of the colour's arm (its home column mouth).
const PLAYERS := {
	"red": {"index": 3, "entry": 51, "home": Vector2i(0, 9),
		"lane": [Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7)]},
	"blue": {"index": 0, "entry": 12, "home": Vector2i(0, 0),
		"lane": [Vector2i(7, 1), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5)]},
	"yellow": {"index": 1, "entry": 25, "home": Vector2i(9, 0),
		"lane": [Vector2i(13, 7), Vector2i(12, 7), Vector2i(11, 7), Vector2i(10, 7), Vector2i(9, 7)]},
	"green": {"index": 2, "entry": 38, "home": Vector2i(9, 9),
		"lane": [Vector2i(7, 13), Vector2i(7, 12), Vector2i(7, 11), Vector2i(7, 10), Vector2i(7, 9)]},
}

static var _ring: Array[Vector2i] = []
static var _ring_index: Dictionary = {}


## The 52 common ring cells, clockwise, starting at the left arm's top row.
static func ring() -> Array[Vector2i]:
	if _ring.is_empty():
		_build_ring()
	return _ring


static func _build_ring() -> void:
	var cells: Array[Vector2i] = []
	for c in range(0, 6): cells.append(Vector2i(c, 6))
	for r in range(5, -1, -1): cells.append(Vector2i(6, r))
	cells.append(Vector2i(7, 0))
	cells.append(Vector2i(8, 0))
	for r in range(1, 6): cells.append(Vector2i(8, r))
	for c in range(9, 15): cells.append(Vector2i(c, 6))
	cells.append(Vector2i(14, 7))
	cells.append(Vector2i(14, 8))
	for c in range(13, 8, -1): cells.append(Vector2i(c, 8))
	for r in range(9, 15): cells.append(Vector2i(8, r))
	cells.append(Vector2i(7, 14))
	cells.append(Vector2i(6, 14))
	for r in range(13, 8, -1): cells.append(Vector2i(6, r))
	for c in range(5, -1, -1): cells.append(Vector2i(c, 8))
	cells.append(Vector2i(0, 7))
	_ring = cells
	_ring_index.clear()
	for i in range(cells.size()):
		_ring_index[cells[i]] = i


## Start square: two ring cells clockwise after the entry.
static func start_of(color: String) -> int:
	return (int(PLAYERS[color]["entry"]) + 2) % RING_LENGTH


## Star square: eight cells after the start (also safe).
static func star_of(color: String) -> int:
	return (start_of(color) + 8) % RING_LENGTH


static func safe_ring_indices() -> Array[int]:
	var out: Array[int] = []
	for color in COLORS:
		out.append(start_of(color))
		out.append(star_of(color))
	out.sort()
	return out


static func is_safe_ring(index: int) -> bool:
	return safe_ring_indices().has(index)


static func ring_index_of(cell: Vector2i) -> int:
	ring()
	return int(_ring_index.get(cell, -1))


## Ring index visited at a common-track progress (1..51).
static func ring_index_for_progress(color: String, progress: int) -> int:
	assert(progress >= 1 and progress <= COMMON_STEPS, "progress %d is not a common-track step" % progress)
	return (start_of(color) + progress - 1) % RING_LENGTH


## Cell for a progress value. Empty dictionary for base or finish.
## Returns {"kind": "ring"|"lane", "cell": Vector2i, "index": int (ring only)}.
static func track_cell(color: String, progress: int) -> Dictionary:
	if progress <= 0 or progress >= FINISH_PROGRESS:
		return {}
	if progress <= COMMON_STEPS:
		var index := ring_index_for_progress(color, progress)
		return {"kind": "ring", "cell": ring()[index], "index": index}
	var lane: Array = PLAYERS[color]["lane"]
	return {"kind": "lane", "cell": lane[progress - COMMON_STEPS - 1]}


## Courtyard spot for a token (0..3), in continuous grid coordinates.
## Measured from the supplied model: the two gold token discs sit 2.2 cells in from
## the courtyard's inner edge (toward the board centre), at 1.1 and 4.1 cells across
## a 6-cell courtyard. Tokens 0 and 1 use those discs; tokens 2 and 3 sit 1.1 cells
## further in, so all four stay clear of the pavilion at the outer edge.
static func base_spot(color: String, token: int) -> Vector2:
	var home: Vector2i = PLAYERS[color]["home"]
	var top_home := home.y < GRID_SIZE / 2
	var inset := 2.2 if token < 2 else 1.1
	var x := 1.9 if token % 2 == 0 else 4.1
	var y := 6.0 - inset if top_home else inset
	return Vector2(home.x + x, home.y + y)


## Continuous grid position for a progress value (used by both renderer and tests).
static func progress_point(color: String, progress: int, token: int = 0) -> Vector2:
	if progress <= 0:
		return base_spot(color, token)
	if progress >= FINISH_PROGRESS:
		var fx := 7.5 + (0.22 if token % 2 == 1 else -0.22)
		var fy := 7.5 + (-0.22 if token < 2 else 0.22)
		return Vector2(fx, fy)
	var cell: Vector2i = track_cell(color, progress)["cell"]
	return Vector2(cell.x + 0.5, cell.y + 0.5)


## Grid to world: board centred on the origin, top surface at y = 0.
## Screen top (row 0) is -Z when the camera looks straight down.
static func to_world(gx: float, gy: float) -> Vector3:
	return Vector3((gx - GRID_SIZE / 2.0) * CELL_SIZE * BOARD_ASPECT_X, 0.0, (gy - GRID_SIZE / 2.0) * CELL_SIZE)
