# Asset inventory: 16 supplied models

Source: `Royal_India_Final_3D_Models_Part_1.zip` (7 models) and
`Royal_India_Final_3D_Models_Part_2.zip` (9 models). The two archives are
different and together make the 16 in the spec. Part 1 was also uploaded
twice; the duplicate is byte-identical and was not used.

Extracted to `godot/assets/models/`, folder structure preserved.
Checked with a glTF parse and a Godot 4.3 headless import
(`godot/tests/asset_check.gd`: 16/16 imported).

| # | File | glTF size | Meshes | Textures | Skins / anims | Measured size (m) | Notes / required work |
|---|------|-----------|--------|----------|---------------|-------------------|------------------------|
| A | 01_Board/Royal_India_Final_Ludo_Board.glb | 6.6 MB | 15 | 0 (colour materials) | none | 12.46 x 3.10 x 12.46 | Board. Must be aligned to the 15x15 grid (see below). |
| B | 02_Dice/Royal_India_Royal_Jewel_Dice.glb | 0.36 MB | 362 | 0 | none | 1.27 cube | Dice. Needs a face-orientation map to verify per-face result. |
| C | 03_Player_Tokens/Royal_Red_Token.glb | 3.9 MB | 8 | 0 | none | 0.56 x 0.87 x 0.56 | Token. 214k triangles: decimate for mobile. |
| C | 03_Player_Tokens/Royal_Green_Token.glb | 3.9 MB | 8 | 0 | none | same | same |
| C | 03_Player_Tokens/Royal_Blue_Token.glb | 3.9 MB | 8 | 0 | none | same | same |
| C | 03_Player_Tokens/Royal_Yellow_Token.glb | 3.9 MB | 8 | 0 | none | same | same |
| D | 04_Character_Limbs/Royal_Red_Token_Folding_Limbs.glb | 0.7 MB | 13 | 0 | none | 0.70 x 0.67 x 0.64 | Static meshes only. Needs a procedural pivot rig. |
| D | 04_Character_Limbs/Royal_Green_Token_Folding_Limbs.glb | 0.7 MB | 13 | 0 | none | same | same |
| D | 04_Character_Limbs/Royal_Blue_Token_Folding_Limbs.glb | 0.7 MB | 13 | 0 | none | same | same |
| D | 04_Character_Limbs/Royal_Yellow_Token_Folding_Limbs.glb | 0.7 MB | 13 | 0 | none | same | same |
| E | 05_Animals_and_Statues/Royal_India_Elephant.glb | 3.7 MB | 91 | 2 | none | 3.69 x 2.67 x 2.08 | Living elephant. No idle animation in the file: add procedural sway if used. |
| E | 05_Animals_and_Statues/Royal_India_Elephant_Statue.glb | 8.6 MB | 7 | 21 | none | 0.94 x 0.96 x 1.30 | Heavy textures: compress. |
| E | 05_Animals_and_Statues/Royal_India_Peacock_HighPoly_Textured.glb | 9.5 MB | 211 | 4 | none | 2.63 x 3.07 x 2.52 | 320k triangles: LOD required. |
| E | 05_Animals_and_Statues/Royal_India_Peacock_Statue.glb | 8.5 MB | 9 | 27 | none | 1.54 x 1.21 x 1.71 | Heavy textures: compress. |
| F | 06_Decorations/Royal_India_Deepam_Lamp_Set.glb | 2.4 MB | 3 | 9 | none | 2.33 x 0.97 x 0.26 | Lamp flame and light positions to be placed. |
| F | 06_Decorations/Royal_India_Lotus_Fountain.glb | 3.5 MB | 9 | 3 | none | 1.87 x 1.87 x 1.34 | Water surface needs a shader; the file has no water. |

## Findings that change the plan

1. **No skeletons and no animations in any of the 16 files.** Every character
   animation (walk, run, jump, transform, punch, kick, grab, throw, victory) must
   be built in code with pivots on the limb meshes, or with an AnimationPlayer
   driving node transforms. This is much more work than the spec assumed.
2. **Token files are heavy.** About 214k triangles per token, 4 tokens per
   colour, all on mobile. Decimation or LOD is required before the game can run
   at 60 fps on a mid-range Android device.
3. **Peacock high-poly is 320k triangles.** Use the `Royal_India_Peacock_Statue`
   file for gameplay-adjacent views and keep the high-poly for a close-up LOD only.
4. **Board and tokens have no textures.** Their colours come from material
   colours only; this is fine for the look of the board, but the spec's marble
   and gold look needs material work.
5. **Total size is about 60 MB** of GLB. Texture compression and decimation are
   needed before Android release.

## Board alignment: not yet verified

The board is 12.46 m wide. The logical grid is 15 cells, so each cell is about
0.83 m if the board spans the whole grid. The actual playfield extent inside the
model still has to be measured from the mesh (tile positions), before tokens can
be placed on it. This is the next step in Phase 3.
