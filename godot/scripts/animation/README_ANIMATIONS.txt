ROYAL INDIA LUDO — PROCEDURAL ANIMATION SCRIPT PACK
Godot 4.x / GDScript

CONTENTS
- transformer_token.gd: supplied coloured token + folding limb controller.
  Includes transform in/out, walk, jump, bump, punch, kick, recoil, grab/throw,
  thrown-to-home, landing, and movement.
- dice_controller.gd: supplied royal jewel dice roll and face orientation controller.
- royal_environment_animator.gd: idle/presentation behaviour for elephant, peacock,
  statues, Deepam lamp, fountain and board.
- royal_fountain_animator.gd: fountain water bob and optional ripple animation.
- royal_token_vfx.gd: selection halo and arrival pulse for token instances.
- royal_camera_animator.gd: focus, shake and reset camera helpers.
- royal_animation_effects.gd: reusable gold impact/transformation/landing ring effects.
- royal_board_animator.gd: subtle board breathing/presentation motion.
- royal_lamp_flicker.gd: flickering lamp lights.

IMPORTANT MODEL LIMITATIONS
GLB files are static geometry unless they contain skeletons/animation tracks. These scripts
provide procedural animation around the supplied models. They do not create realistic
elephant leg motion or peacock feather articulation when those meshes have no rig/bones.
For those, create a rig in Blender or add separate articulated mesh parts and pivots.

TOKEN SCENE SETUP
1. Create a Node3D root for each token instance.
2. Attach transformer_token.gd to that root.
3. Call configure("red"), configure("blue"), configure("green"), or configure("yellow")
   once after adding the node to the scene tree.
4. Ensure the res://assets paths in transformer_token.gd match the imported GLB paths.
5. The script expects limb mesh node names to include patterns such as:
   arm_L_shoulder, arm_R_elbow, leg_L_hip, leg_R_knee, etc.
   If the supplied GLB names differ, update the routing map after inspecting the GLB.
6. Use await token.play_walk(), await token.play_jump(), await token.play_punch(target),
   await token.play_kick(target), or await token.play_grab_throw(target, home_position).
7. The target token must also use TransformerToken for recoil/throw methods.

DICE SCENE SETUP
1. Create Area3D root with a child Node3D named DiceModel.
2. Attach dice_controller.gd to Area3D.
3. Ensure collision shape covers the tappable dice.
4. Connect dice_rolled(result) to your turn/rules manager.
5. Verify the GLB's face orientation in Godot; update _orientation_for_result() if needed.

ENVIRONMENT SETUP
Attach royal_environment_animator.gd to each environment GLB root and select its type.
For fountain, use royal_fountain_animator.gd and assign water/ripple nodes.
For lamps, add Light3D nodes and use royal_lamp_flicker.gd or environment animator.
For the board, use royal_board_animator.gd only for menu/presentation scenes; avoid moving
the board root during active gameplay because path coordinates must remain stable.

TESTING
These scripts have not been run in the Godot editor in this environment. Open the project
in the same Godot 4.x version, inspect model node names and pivots, run the debugger, and
correct any GLB-specific orientation/name mismatches before shipping.
