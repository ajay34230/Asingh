## Headless test runner for the game logic.
## Run from the godot/ folder:
##   godot --headless --path . --script res://tests/run_tests.gd
extends SceneTree

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	_test_ring_topology()
	_test_track_mapping()
	_test_start_and_safe_squares()
	_test_base_exit_needs_six()
	_test_exact_finish()
	_test_capture_sends_victim_home()
	_test_safe_square_blocks_capture()
	_test_six_gives_bonus_turn()
	_test_three_sixes_forfeit()
	_test_no_legal_move_passes()
	_test_finish_ranks_and_game_over()
	_test_every_colour_reaches_home()
	_test_ai_full_games_finish()
	_test_house_rules()
	_test_ai_difficulties_finish()

	print("%d checks, %d failures" % [_checks, _failures.size()])
	for message in _failures:
		print("FAIL: " + message)
	quit(1 if _failures.size() > 0 else 0)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _engine(seats: Array, rng_seed: int = 7) -> RulesEngine:
	var e := RulesEngine.new()
	e.setup(seats, rng_seed)
	return e


func _four_seats() -> Array:
	return [
		{"color": "red", "human": true}, {"color": "green", "human": false},
		{"color": "yellow", "human": false}, {"color": "blue", "human": false},
	]


func _test_ring_topology() -> void:
	var ring := BoardPath.ring()
	check(ring.size() == 52, "ring has 52 cells")
	var seen := {}
	var diagonals := 0
	for i in range(52):
		seen[ring[i]] = true
		var a: Vector2i = ring[i]
		var b: Vector2i = ring[(i + 1) % 52]
		var d := absi(a.x - b.x) + absi(a.y - b.y)
		if d != 1:
			check(absi(a.x - b.x) == 1 and absi(a.y - b.y) == 1, "step %d is a legal step" % i)
			diagonals += 1
	check(seen.size() == 52, "ring cells are unique")
	check(diagonals == 4, "exactly four inner-corner diagonal steps")
	for color in BoardPath.COLORS:
		var lane: Array = BoardPath.PLAYERS[color]["lane"]
		check(lane.size() == 5, "%s lane has five cells" % color)


func _test_track_mapping() -> void:
	for color in BoardPath.COLORS:
		var visited := {}
		for p in range(1, BoardPath.COMMON_STEPS + 1):
			visited[BoardPath.ring_index_for_progress(color, p)] = true
		check(visited.size() == 51, "%s visits 51 distinct ring cells" % color)
		check(BoardPath.ring_index_for_progress(color, 1) == BoardPath.start_of(color), "%s starts on its start square" % color)
		check(BoardPath.track_cell(color, 52)["kind"] == "lane", "%s enters its lane at 52" % color)
		check(BoardPath.track_cell(color, BoardPath.FINISH_PROGRESS).is_empty(), "%s finish has no track cell" % color)


func _test_start_and_safe_squares() -> void:
	var starts: Array[int] = []
	for color in BoardPath.COLORS:
		starts.append(BoardPath.start_of(color))
	starts.sort()
	for i in range(1, starts.size()):
		check(starts[i] - starts[i - 1] == 13, "start squares are 13 apart")
	check(BoardPath.safe_ring_indices().size() == 8, "eight safe squares")


func _test_base_exit_needs_six() -> void:
	var e := _engine(_four_seats())
	var first := e.roll_with_value(5)
	check(first["passed"], "a five with all tokens home passes the turn")
	check(e.current == 1, "turn moved to the next seat")
	e.current = 0
	e.phase = RulesEngine.PHASE_ROLL
	var six := e.roll_with_value(6)
	check(six["moves"] == [0, 1, 2, 3], "every base token can leave on a six")
	e.apply_move(2)
	check(e.seats[0]["tokens"][2] == 1, "token leaves base onto progress 1")


func _test_exact_finish() -> void:
	var e := _engine(_four_seats())
	e.seats[0]["tokens"] = [55, 0, 0, 0]
	var overshoot := e.roll_with_value(3)
	check(overshoot["passed"], "55 cannot take a 3")
	e.seats[0]["tokens"] = [55, 0, 0, 0]
	e.current = 0
	e.phase = RulesEngine.PHASE_ROLL
	e.roll_with_value(2)
	check(e.legal_moves() == [0], "55 can take an exact 2")
	var result := e.apply_move(0)
	check(result["finishes"], "exact roll finishes")


func _test_capture_sends_victim_home() -> void:
	var e := _engine(_four_seats())
	e.seats[0]["tokens"] = [20, 0, 0, 0]
	var target := BoardPath.ring_index_for_progress("red", 23)
	var green_progress := ((target - BoardPath.start_of("green") + 52) % 52) + 1
	e.seats[1]["tokens"] = [green_progress, 0, 0, 0]
	e.roll_with_value(3)
	var result := e.apply_move(0)
	check(result["captured"].size() == 1, "landing on an opponent captures it")
	check(e.seats[1]["tokens"][0] == 0, "captured token returns to base")


func _test_safe_square_blocks_capture() -> void:
	var e := _engine(_four_seats())
	e.seats[0]["tokens"] = [6, 0, 0, 0]
	var star := BoardPath.star_of("red")
	var green_progress := ((star - BoardPath.start_of("green") + 52) % 52) + 1
	e.seats[1]["tokens"] = [green_progress, 0, 0, 0]
	e.roll_with_value(3)
	var preview := e.preview_move(0)
	check(preview["to"] == 9, "red lands on its star square")
	check(preview["captures"].is_empty(), "star square is safe from capture")


func _test_six_gives_bonus_turn() -> void:
	var e := _engine(_four_seats())
	e.roll_with_value(6)
	var first := e.apply_move(0)
	check(first["extra_turn"], "six gives a bonus turn")
	check(e.current == 0 and e.phase == RulesEngine.PHASE_ROLL, "same seat rolls again")
	e.roll_with_value(4)
	e.apply_move(0)
	check(e.current == 1, "turn passes after a non-six")


func _test_three_sixes_forfeit() -> void:
	var e := _engine(_four_seats())
	e.seats[0]["tokens"] = [5, 0, 0, 0]
	e.roll_with_value(6)
	e.apply_move(0)
	e.roll_with_value(6)
	e.apply_move(0)
	var third := e.roll_with_value(6)
	check(third["forfeited"], "three sixes forfeit the turn")
	check(e.current == 1, "turn passes after forfeit")
	check(e.seats[0]["tokens"][0] == 17, "the third six is void")


func _test_no_legal_move_passes() -> void:
	var e := _engine(_four_seats())
	var outcome := e.roll_with_value(2)
	check(outcome["passed"] and e.current == 1, "no legal move passes the turn")


func _test_finish_ranks_and_game_over() -> void:
	var e := _engine([{"color": "red", "human": true}, {"color": "yellow", "human": false}])
	e.seats[0]["tokens"] = [57, 57, 57, 55]
	e.seats[1]["tokens"] = [57, 57, 57, 0]
	e.roll_with_value(2)
	var result := e.apply_move(3)
	check(result["game_over"], "last active seat ends the game")
	check(e.phase == RulesEngine.PHASE_OVER, "phase is over")
	check(e.rankings == [0, 1], "rankings are recorded in order")


func _test_every_colour_reaches_home() -> void:
	# A single token walked with exact rolls must reach progress 57 for every colour.
	for color in BoardPath.COLORS:
		var other := "blue" if color != "blue" else "red"
		var e := _engine([{"color": color, "human": true}, {"color": other, "human": false}], 3)
		var steps := 0
		var reached := false
		while steps < 2000 and not reached:
			if e.phase != RulesEngine.PHASE_ROLL:
				e.phase = RulesEngine.PHASE_ROLL
			e.current = 0
			var r := e.roll_with_value(1 + steps % 6)
			if r["moves"].size() > 0:
				var pick: int = r["moves"][0]
				e.apply_move(pick)
			if e.seats[0]["tokens"][0] == BoardPath.FINISH_PROGRESS:
				reached = true
			steps += 1
		check(reached, "%s token reaches home" % color)
		check(e.seats[0]["tokens"][0] == BoardPath.FINISH_PROGRESS, "%s token ends exactly on the finish" % color)


func _test_ai_full_games_finish() -> void:
	for seed_value in range(1, 21):
		var e := _engine([
			{"color": "red", "human": false}, {"color": "green", "human": false},
			{"color": "yellow", "human": false}, {"color": "blue", "human": false},
		], seed_value)
		var turns := 0
		while e.phase != RulesEngine.PHASE_OVER and turns < 20000:
			var outcome := e.roll()
			if e.phase == RulesEngine.PHASE_MOVE:
				var choice := AiController.choose_move(e, outcome["moves"])
				check(outcome["moves"].has(choice), "AI picks a legal move")
				e.apply_move(choice)
			turns += 1
		check(e.phase == RulesEngine.PHASE_OVER, "AI game %d finishes" % seed_value)
		check(e.rankings.size() == 4, "AI game %d ranks all four seats" % seed_value)


func _test_house_rules() -> void:
	# Six to start off: a token leaves the yard on any roll.
	var e := RulesEngine.new()
	e.setup([{"color": "blue", "human": true}, {"color": "green", "human": false}], 5, {"six_to_start": false})
	e.roll_with_value(2)
	check(e.legal_moves().size() == 4, "any roll brings a token out when six_to_start is off")

	# Capture bonus off: a capture passes the turn.
	e = RulesEngine.new()
	e.setup([{"color": "blue", "human": true}, {"color": "green", "human": false}], 5, {"capture_bonus": false})
	e.seats[0]["tokens"] = [10, 0, 0, 0]
	var target := BoardPath.ring_index_for_progress("blue", 13)
	e.seats[1]["tokens"] = [((target - BoardPath.start_of("green") + 52) % 52) + 1, 0, 0, 0]
	e.roll_with_value(3)
	var result := e.apply_move(0)
	check(result["captured"].size() == 1 and not result["extra_turn"], "capture gives no bonus when capture_bonus is off")

	# Three sixes penalty off: the third six is a normal move.
	e = RulesEngine.new()
	e.setup([{"color": "blue", "human": true}, {"color": "green", "human": false}], 5, {"three_sixes_penalty": false})
	e.seats[0]["tokens"] = [5, 0, 0, 0]
	for i in range(3):
		e.roll_with_value(6)
		e.apply_move(0)
	check(e.current == 0 and e.seats[0]["tokens"][0] == 23, "three sixes do not forfeit when the penalty is off")

	# Quick end: the game stops at the first finish, and the rest are ranked by progress.
	e = RulesEngine.new()
	e.setup([{"color": "blue", "human": true}, {"color": "green", "human": false}, {"color": "red", "human": false}], 5, {"quick_end": true})
	e.seats[0]["tokens"] = [57, 57, 57, 55]
	e.seats[1]["tokens"] = [40, 0, 0, 0]
	e.seats[2]["tokens"] = [10, 0, 0, 0]
	e.roll_with_value(2)
	e.apply_move(3)
	check(e.phase == RulesEngine.PHASE_OVER and e.rankings.size() == 3, "quick end ranks everyone and ends the game")
	check(e.rankings == [0, 1, 2], "remaining seats are ranked by progress")


func _test_ai_difficulties_finish() -> void:
	for difficulty in range(4):
		for seed_value in range(1, 6):
			var e := _engine([
				{"color": "red", "human": false}, {"color": "green", "human": false},
				{"color": "yellow", "human": false}, {"color": "blue", "human": false},
			], seed_value)
			var turns := 0
			while e.phase != RulesEngine.PHASE_OVER and turns < 20000:
				var outcome := e.roll()
				if e.phase == RulesEngine.PHASE_MOVE:
					var choice := AiController.choose_move(e, outcome["moves"], difficulty)
					check(outcome["moves"].has(choice), "difficulty %d picks a legal move" % difficulty)
					e.apply_move(choice)
				turns += 1
			check(e.phase == RulesEngine.PHASE_OVER, "difficulty %d game %d finishes" % [difficulty, seed_value])

