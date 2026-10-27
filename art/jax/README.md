# Jax Mercer: 3D character model

Jax is built entirely by the Python scripts in `scripts/`, which run in Blender 5.2.
They follow the Riftfall character sheet: dark open jacket over a grey shirt,
cargo pants, brown boots and gear, the glowing wrist unit for Serra on his left
forearm, a dog tag and a backpack.

- `export/Jax_Mercer_R15.fbx` is the model to import into Roblox Studio.
  It has an R15 skeleton and 15 body parts named `*_Geo`, it is 5.7 studs tall,
  and its PBR textures are built into the file. See `HOW_TO_IMPORT_JAX.md`.
- `previews/` holds the rendered pictures and a walking-pose test of the skin weights.

## Rebuild

```
pip install bpy==5.2.3          # Blender as a Python module (Python 3.13)
python scripts/build_geo.py  /tmp/jax_geo.blend
python scripts/build_final.py /tmp/jax_geo.blend art/jax/export 2048
python scripts/verify_fbx.py art/jax/export/Jax_Mercer_R15.fbx /tmp/jax_posed.blend
python scripts/render_views.py art/jax/export/Jax_Mercer.blend /tmp/renders front,back,side,threequarter,face34
```

`verify_fbx.py` re-imports the FBX and checks it against Roblox's R15
rules: bone hierarchy, part names, a maximum of 4 influences per vertex, no
weights on the Root bone, under 20,000 triangles per part, embedded textures
and height.
