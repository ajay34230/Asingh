# The Lost Kingdom - downloadable characters

This branch only holds the characters the game downloads on demand, so the APK stays small.
`heroes/<id>.glb` is the model (animations stripped; the game drives the Mixamo rig with its own clips),
`heroes/<id>.png` its portrait, and `heroes/all_characters.png` a sheet of all of them.

The models are Mixamo characters (Adobe), converted from FBX to GLB with `tools/convert_heroes.gd`
on the main branch. See ASSETS.md there.
