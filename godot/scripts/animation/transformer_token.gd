extends Node3D
class_name TransformerToken

## Royal India Ludo token controller.
## The coloured jewel pawn remains the core body; separate limb meshes are
## grouped into shoulder/elbow/wrist and hip/knee/ankle pivots at runtime.

var team: String = "red"
var body_scene: PackedScene
var limb_scene: PackedScene
var body_node: Node3D
var limb_root: Node3D
var arm_pivots: Dictionary = {}
var leg_pivots: Dictionary = {}
var active_tween: Tween
var is_transformed := false
var is_moving := false
var path_index := -1
var has_left_home := false
## Which model to build: "robot" (RoboPawn), "royal" (RoyalPawn) or "original" (the
## supplied GLB models). Set from the "Token model" setting; tests may override it.
static var style_override := ""


static func current_style() -> String:
    if style_override != "":
        return style_override
    return String(GameSettings.get_option("token_style"))


## The body alone, for statuettes (plaques).
static func build_statue(color: String) -> Node3D:
    match current_style():
        "robot":
            return RoboPawn.build_body(color)
        "royal":
            return RoyalPawn.build_body(color)
    return (load(BODY_PATHS[color]) as PackedScene).instantiate() as Node3D

## Height of the token root when standing on the board. The game sets this per square.
var ground_y := 0.25

const BODY_PATHS := {
    "red": "res://assets/models/03_Player_Tokens/Royal_Red_Token.glb",
    "blue": "res://assets/models/03_Player_Tokens/Royal_Blue_Token.glb",
    "green": "res://assets/models/03_Player_Tokens/Royal_Green_Token.glb",
    "yellow": "res://assets/models/03_Player_Tokens/Royal_Yellow_Token.glb"
}
const LIMB_PATHS := {
    "red": "res://assets/models/04_Character_Limbs/Royal_Red_Token_Folding_Limbs.glb",
    "blue": "res://assets/models/04_Character_Limbs/Royal_Blue_Token_Folding_Limbs.glb",
    "green": "res://assets/models/04_Character_Limbs/Royal_Green_Token_Folding_Limbs.glb",
    "yellow": "res://assets/models/04_Character_Limbs/Royal_Yellow_Token_Folding_Limbs.glb"
}

func configure(team_colour: String) -> void:
    team = team_colour.to_lower()
    var style := current_style()
    if style == "robot" or style == "royal":
        ## Models built in code: realistic robots, or the polished royal pawn.
        body_node = RoboPawn.build_body(team) if style == "robot" else RoyalPawn.build_body(team)
        body_node.name = "JewelPawnBody"
        add_child(body_node)
        limb_root = Node3D.new()
        limb_root.name = "TransformerLimbRig"
        add_child(limb_root)
        _build_pivots()
        if style == "robot":
            RoboPawn.dress_limbs(team, arm_pivots, leg_pivots)
        else:
            RoyalPawn.dress_limbs(self, team, arm_pivots, leg_pivots)
        _fold_pose()
        return
    body_scene = load(BODY_PATHS[team]) as PackedScene
    limb_scene = load(LIMB_PATHS[team]) as PackedScene
    body_node = body_scene.instantiate() as Node3D
    body_node.name = "JewelPawnBody"
    add_child(body_node)
    limb_root = limb_scene.instantiate() as Node3D
    limb_root.name = "TransformerLimbRig"
    add_child(limb_root)
    _build_pivots()
    _fold_pose()

func _build_pivots() -> void:
    var sides := [-1, 1]
    for side in sides:
        var side_name := "L" if side < 0 else "R"
        var shoulder_pos := Vector3(side * 0.245, 0.575, 0.0)
        var elbow_pos := Vector3(side * 0.275, 0.375, 0.045)
        var wrist_pos := Vector3(side * 0.125, 0.275, 0.135)
        var shoulder := _make_pivot("ArmShoulder" + side_name, limb_root, shoulder_pos)
        var elbow := _make_pivot("ArmElbow" + side_name, shoulder, elbow_pos - shoulder_pos)
        var wrist := _make_pivot("ArmWrist" + side_name, elbow, wrist_pos - elbow_pos)
        arm_pivots[side_name] = {"shoulder": shoulder, "elbow": elbow, "wrist": wrist}

        var hip_pos := Vector3(side * 0.115, 0.215, 0.005)
        var knee_pos := Vector3(side * 0.17, 0.105, 0.055)
        var ankle_pos := Vector3(side * 0.095, 0.07, 0.145)
        var hip := _make_pivot("LegHip" + side_name, limb_root, hip_pos)
        var knee := _make_pivot("LegKnee" + side_name, hip, knee_pos - hip_pos)
        var ankle := _make_pivot("LegAnkle" + side_name, knee, ankle_pos - knee_pos)
        leg_pivots[side_name] = {"hip": hip, "knee": knee, "ankle": ankle}

    # The optimized limb GLB contains one vertex-coloured mesh per articulated
    # segment. Route each segment by its stable node name, keeping draw calls low.
    var mesh_nodes: Array[MeshInstance3D] = []
    _collect_meshes(limb_root, mesh_nodes)
    for mesh_node in mesh_nodes:
        var node_name := String(mesh_node.name)
        var destination: Node3D = limb_root
        for side_name in ["L", "R"]:
            var arm: Dictionary = arm_pivots[side_name]
            var leg: Dictionary = leg_pivots[side_name]
            if node_name.contains("arm_" + side_name + "_shoulder"):
                destination = arm["shoulder"]
            elif node_name.contains("arm_" + side_name + "_elbow"):
                destination = arm["elbow"]
            elif node_name.contains("arm_" + side_name + "_wrist"):
                destination = arm["wrist"]
            elif node_name.contains("leg_" + side_name + "_hip"):
                destination = leg["hip"]
            elif node_name.contains("leg_" + side_name + "_knee"):
                destination = leg["knee"]
            elif node_name.contains("leg_" + side_name + "_ankle"):
                destination = leg["ankle"]
        mesh_node.reparent(destination, true)

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            output.append(child)
        _collect_meshes(child, output)

func _make_pivot(node_name: String, parent_node: Node3D, local_pos: Vector3) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = node_name
    pivot.position = local_pos
    parent_node.add_child(pivot)
    return pivot

func _fold_pose() -> void:
    for side_name in arm_pivots:
        var arm: Dictionary = arm_pivots[side_name]
        arm["shoulder"].rotation = Vector3.ZERO
        arm["elbow"].rotation = Vector3.ZERO
        arm["wrist"].rotation = Vector3.ZERO
    for side_name in leg_pivots:
        var leg: Dictionary = leg_pivots[side_name]
        leg["hip"].rotation = Vector3.ZERO
        leg["knee"].rotation = Vector3.ZERO
        leg["ankle"].rotation = Vector3.ZERO

func _new_tween() -> Tween:
    if active_tween and active_tween.is_running():
        active_tween.kill()
    active_tween = create_tween()
    return active_tween

func transform_out(duration: float = 0.42) -> void:
    if is_transformed:
        return
    is_transformed = true
    var tween := _new_tween().set_parallel(true)
    for side_name in arm_pivots:
        var side := -1.0 if side_name == "L" else 1.0
        var arm: Dictionary = arm_pivots[side_name]
        tween.tween_property(arm["shoulder"], "rotation:z", -side * 0.48, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(arm["elbow"], "rotation:z", side * 0.30, duration * 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tween.tween_property(arm["wrist"], "rotation:x", side * 0.16, duration * 0.7)
    for side_name in leg_pivots:
        var side := -1.0 if side_name == "L" else 1.0
        var leg: Dictionary = leg_pivots[side_name]
        tween.tween_property(leg["hip"], "rotation:z", side * 0.32, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(leg["knee"], "rotation:z", -side * 0.22, duration * 0.8)
        tween.tween_property(leg["ankle"], "rotation:z", -side * 0.10, duration * 0.7)
    await tween.finished

func transform_in(duration: float = 0.38) -> void:
    if not is_transformed:
        return
    is_transformed = false
    var tween := _new_tween().set_parallel(true)
    for side_name in arm_pivots:
        var arm: Dictionary = arm_pivots[side_name]
        tween.tween_property(arm["shoulder"], "rotation", Vector3.ZERO, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
        tween.tween_property(arm["elbow"], "rotation", Vector3.ZERO, duration)
        tween.tween_property(arm["wrist"], "rotation", Vector3.ZERO, duration)
    for side_name in leg_pivots:
        var leg: Dictionary = leg_pivots[side_name]
        tween.tween_property(leg["hip"], "rotation", Vector3.ZERO, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
        tween.tween_property(leg["knee"], "rotation", Vector3.ZERO, duration)
        tween.tween_property(leg["ankle"], "rotation", Vector3.ZERO, duration)
    await tween.finished

func play_walk(duration: float = 0.48) -> void:
    if not is_transformed:
        await transform_out(0.25)
    is_moving = true
    var half := duration / 3.0
    var step_a := create_tween().set_parallel(true)
    active_tween = step_a
    for side_name in arm_pivots:
        var side := -1.0 if side_name == "L" else 1.0
        var arm: Dictionary = arm_pivots[side_name]
        var leg: Dictionary = leg_pivots[side_name]
        step_a.tween_property(arm["shoulder"], "rotation:z", -side * 0.25, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        step_a.tween_property(leg["hip"], "rotation:z", side * 0.34, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        step_a.tween_property(leg["knee"], "rotation:z", 0.18, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    step_a.tween_property(body_node, "position:y", 0.055, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    await step_a.finished

    var step_b := create_tween().set_parallel(true)
    active_tween = step_b
    for side_name in arm_pivots:
        var side := -1.0 if side_name == "L" else 1.0
        var arm: Dictionary = arm_pivots[side_name]
        var leg: Dictionary = leg_pivots[side_name]
        step_b.tween_property(arm["shoulder"], "rotation:z", side * 0.25, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        step_b.tween_property(leg["hip"], "rotation:z", -side * 0.34, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        step_b.tween_property(leg["knee"], "rotation:z", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    step_b.tween_property(body_node, "position:y", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    await step_b.finished

    var settle := create_tween().set_parallel(true)
    active_tween = settle
    for side_name in arm_pivots:
        var arm: Dictionary = arm_pivots[side_name]
        var leg: Dictionary = leg_pivots[side_name]
        settle.tween_property(arm["shoulder"], "rotation:z", 0.0, half)
        settle.tween_property(leg["hip"], "rotation:z", 0.0, half)
    await settle.finished
    is_moving = false

func play_jump() -> void:
    if not is_transformed:
        await transform_out(0.24)
    var tween := _new_tween()
    tween.tween_property(self, "position:y", position.y + 0.42, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(body_node, "scale", Vector3(0.92, 1.12, 0.92), 0.16)
    tween.tween_property(self, "position:y", position.y, 0.30).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(body_node, "scale", Vector3.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await tween.finished

func play_bump(direction: Vector3 = Vector3.RIGHT) -> void:
    var push := direction.normalized() * 0.20
    var original := position
    var tween := _new_tween()
    tween.tween_property(self, "position", original + push, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(self, "rotation:y", rotation.y + deg_to_rad(24.0), 0.10)
    tween.tween_property(self, "position", original - push * 0.22, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(body_node, "scale", Vector3(1.10, 0.82, 1.10), 0.08)
    tween.tween_property(self, "position", original, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(body_node, "scale", Vector3.ONE, 0.20)
    tween.parallel().tween_property(self, "rotation:y", rotation.y, 0.18)
    await tween.finished


func _face_world_point(point: Vector3) -> void:
    var flat := point - global_position
    flat.y = 0.0
    if flat.length_squared() > 0.0001:
        rotation.y = atan2(flat.x, flat.z)  ## the model's front (where the limbs reach) is +Z

func play_punch(target: Node3D) -> void:
    if not is_transformed:
        await transform_out(0.22)
    _face_world_point(target.global_position)
    var lead: Dictionary = arm_pivots["R"]
    var support: Dictionary = arm_pivots["L"]
    var wind := create_tween().set_parallel(true)
    wind.tween_property(lead["shoulder"], "rotation:x", -0.42, 0.10)
    wind.tween_property(lead["elbow"], "rotation:x", 0.62, 0.10)
    wind.tween_property(support["shoulder"], "rotation:x", -0.18, 0.10)
    wind.tween_property(self, "position:y", position.y + 0.035, 0.10)
    await wind.finished
    var strike := create_tween().set_parallel(true)
    strike.tween_property(lead["shoulder"], "rotation:x", -1.32, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    strike.tween_property(lead["elbow"], "rotation:x", 0.12, 0.09)
    strike.tween_property(lead["wrist"], "rotation:x", -0.20, 0.09)
    strike.tween_property(self, "position", global_position + (global_basis.z.normalized() * 0.13), 0.09)
    await strike.finished
    await target.play_hit_recoil(global_basis.z)
    var recover := create_tween().set_parallel(true)
    recover.tween_property(lead["shoulder"], "rotation", Vector3.ZERO, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    recover.tween_property(lead["elbow"], "rotation", Vector3.ZERO, 0.18)
    recover.tween_property(lead["wrist"], "rotation", Vector3.ZERO, 0.18)
    recover.tween_property(support["shoulder"], "rotation", Vector3.ZERO, 0.18)
    recover.tween_property(self, "position:y", ground_y, 0.20)
    await recover.finished

func play_kick(target: Node3D) -> void:
    if not is_transformed:
        await transform_out(0.22)
    _face_world_point(target.global_position)
    var leg: Dictionary = leg_pivots["R"]
    var support: Dictionary = leg_pivots["L"]
    var brace := create_tween().set_parallel(true)
    brace.tween_property(support["hip"], "rotation:z", -0.20, 0.10)
    brace.tween_property(support["knee"], "rotation:z", 0.12, 0.10)
    brace.tween_property(body_node, "rotation:z", -0.12, 0.10)
    brace.tween_property(leg["hip"], "rotation:x", -0.55, 0.10)
    await brace.finished
    var kick := create_tween().set_parallel(true)
    kick.tween_property(leg["hip"], "rotation:x", -1.42, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    kick.tween_property(leg["knee"], "rotation:x", 0.78, 0.13)
    kick.tween_property(leg["ankle"], "rotation:x", -0.28, 0.13)
    kick.tween_property(self, "position", global_position + (global_basis.z.normalized() * 0.12), 0.13)
    await kick.finished
    await target.play_hit_recoil(global_basis.z)
    var land := create_tween().set_parallel(true)
    land.tween_property(leg["hip"], "rotation", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
    land.tween_property(leg["knee"], "rotation", Vector3.ZERO, 0.20)
    land.tween_property(leg["ankle"], "rotation", Vector3.ZERO, 0.20)
    land.tween_property(support["hip"], "rotation", Vector3.ZERO, 0.20)
    land.tween_property(support["knee"], "rotation", Vector3.ZERO, 0.20)
    land.tween_property(body_node, "rotation", Vector3.ZERO, 0.20)
    land.tween_property(self, "position:y", ground_y, 0.22)
    await land.finished

func play_hit_recoil(from_direction: Vector3) -> void:
    if not is_transformed:
        await transform_out(0.18)
    var away := from_direction.normalized()
    if away.length_squared() < 0.01:
        away = Vector3.BACK
    var start := global_position
    var recoil := create_tween().set_parallel(true)
    recoil.tween_property(self, "global_position", start + away * 0.22 + Vector3.UP * 0.10, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    recoil.tween_property(self, "rotation:z", rotation.z + 0.28, 0.12)
    recoil.tween_property(body_node, "scale", Vector3(0.88, 1.13, 0.88), 0.12)
    for side_name in arm_pivots:
        var arm: Dictionary = arm_pivots[side_name]
        recoil.tween_property(arm["shoulder"], "rotation:x", -0.48, 0.12)
    await recoil.finished
    var stagger := create_tween().set_parallel(true)
    stagger.tween_property(self, "global_position", start - away * 0.045, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    stagger.tween_property(self, "rotation:z", 0.0, 0.20)
    stagger.tween_property(body_node, "scale", Vector3.ONE, 0.20)
    for side_name in arm_pivots:
        var arm: Dictionary = arm_pivots[side_name]
        stagger.tween_property(arm["shoulder"], "rotation", Vector3.ZERO, 0.20)
    await stagger.finished

func play_grab_throw(target: Node3D, home_position: Vector3) -> void:
    if not is_transformed:
        await transform_out(0.22)
    _face_world_point(target.global_position)
    var left: Dictionary = arm_pivots["L"]
    var right: Dictionary = arm_pivots["R"]
    # Reach with both arms, close hands around the opponent, then lift.
    var grab := create_tween().set_parallel(true)
    grab.tween_property(left["shoulder"], "rotation:x", -0.88, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    grab.tween_property(right["shoulder"], "rotation:x", -0.88, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    grab.tween_property(left["elbow"], "rotation:x", 0.82, 0.18)
    grab.tween_property(right["elbow"], "rotation:x", 0.82, 0.18)
    grab.tween_property(left["wrist"], "rotation:z", -0.28, 0.18)
    grab.tween_property(right["wrist"], "rotation:z", 0.28, 0.18)
    grab.tween_property(self, "position:y", position.y + 0.08, 0.18)
    await grab.finished
    # Brief lift/hold beat makes the grab readable before the throw.
    var lift_start := target.global_position
    var lift := create_tween()
    lift.tween_property(target, "global_position", lift_start + Vector3.UP * 0.42, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    lift.parallel().tween_property(target, "rotation:z", target.rotation.z + 0.55, 0.20)
    await lift.finished
    await target.play_thrown_to_home(home_position)
    var release := create_tween().set_parallel(true)
    release.tween_property(left["shoulder"], "rotation", Vector3.ZERO, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    release.tween_property(right["shoulder"], "rotation", Vector3.ZERO, 0.24)
    release.tween_property(left["elbow"], "rotation", Vector3.ZERO, 0.22)
    release.tween_property(right["elbow"], "rotation", Vector3.ZERO, 0.22)
    release.tween_property(left["wrist"], "rotation", Vector3.ZERO, 0.22)
    release.tween_property(right["wrist"], "rotation", Vector3.ZERO, 0.22)
    release.tween_property(self, "position:y", ground_y, 0.24)
    await release.finished

func play_thrown_to_home(home_position: Vector3) -> void:
    if not is_transformed:
        await transform_out(0.16)
    var start := global_position
    var end := home_position
    var span := Vector2(end.x - start.x, end.z - start.z).length()
    var duration := 0.62 + span * 0.045
    var flight := create_tween()
    flight.tween_method(Callable(self, "_update_throw").bind(start, end, 0.72 + span * 0.22), 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    await flight.finished
    global_position = end
    rotation = Vector3.ZERO
    body_node.scale = Vector3.ONE
    await play_landing_impact()
    await transform_in(0.32)

func _update_throw(progress: float, start: Vector3, end: Vector3, arc: float = 0.72) -> void:
    global_position = start.lerp(end, progress) + Vector3.UP * sin(progress * PI) * arc
    rotation.z = sin(progress * PI * 2.0) * 0.9
    rotation.x = progress * TAU
    body_node.scale = Vector3.ONE * (1.0 - 0.18 * sin(progress * PI))

func play_landing_impact() -> void:
    var impact := create_tween().set_parallel(true)
    impact.tween_property(self, "position:y", position.y - 0.10, 0.07)
    impact.tween_property(body_node, "scale", Vector3(1.13, 0.78, 1.13), 0.07)
    await impact.finished
    var settle := create_tween().set_parallel(true)
    settle.tween_property(self, "position:y", ground_y, 0.20).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
    settle.tween_property(body_node, "scale", Vector3.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await settle.finished

func move_to_world(target: Vector3, duration: float = 0.45) -> void:
    if not is_transformed:
        await transform_out(0.22)
    is_moving = true
    var start := global_position
    var travel := create_tween()
    var flat := Vector3(target.x - start.x, 0, target.z - start.z)
    var heading := atan2(flat.x, flat.z) if flat.length_squared() > 0.0004 else rotation.y
    travel.tween_method(Callable(self, "_update_move").bind(start, target, rotation.y, heading), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await travel.finished
    body_node.position.y = 0.0
    is_moving = false

func _update_move(progress: float, start: Vector3, target: Vector3, from_heading := 0.0, heading := 0.0) -> void:
    global_position = start.lerp(target, progress)
    rotation.y = lerp_angle(from_heading, heading, minf(1.0, progress * 3.0))  ## turn to face the way it walks
    body_node.position.y = absf(sin(progress * PI * 2.0)) * 0.075

func play_home_bounce() -> void:
    await play_jump()
    await transform_in(0.28)
