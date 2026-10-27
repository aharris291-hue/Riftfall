# Put Jax Mercer into Roblox Studio

The file you need is **Jax_Mercer_R15.fbx**. Its four textures are built into
it, so it is the only file you have to pick.

## Steps

1. Open your Riftfall place in Roblox Studio.
2. Click the **Avatar** tab at the top, then click **Import 3D**.
   (Or use **File > Import 3D**.)
3. Find **Jax_Mercer_R15.fbx** and click **Open**. A preview window opens
   showing Jax.
4. On the right side of that window, check three settings:
   - **Rig General > Rig Type**: set it to **R15**.
   - **Rig General > Rig Scale**: set it to **Rthro**.
   - **File Geometry > Scale Unit**: set it to **Stud**.
5. Click **Import** at the bottom. Jax appears in the world, about 5.7
   studs tall.
6. On the right, find the **Explorer** window. Jax shows up there as a model
   called **Jax_Mercer**. Right-click it, choose **Rename**, and type
   `StarterCharacter`.
7. Drag **StarterCharacter** onto **StarterPlayer** in the Explorer.
8. Press **Play**. You now play as Jax.

## If something looks wrong

- **Jax is plain grey with no colors:** click **Window > Asset Manager**,
  click **Import**, and upload the four PNG files (`Jax_ALB`, `Jax_NOR`,
  `Jax_RGH`, `Jax_MTL`). Then click each body part inside Jax and add a
  **SurfaceAppearance**. Set **ColorMap** to ALB, **NormalMap** to NOR,
  **RoughnessMap** to RGH and **MetalnessMap** to MTL.
- **Jax is huge or tiny:** delete him and import again. This time make sure
  Scale Unit is set to **Stud**.
- **Old outfit pieces appear on top of Jax:** the game's outfit code is still
  dressing him. That code needs a small switch so it leaves the custom model
  alone. Claude handles this switch when it swaps Jax in for you.

## What's in this folder

| File | What it is |
|---|---|
| `Jax_Mercer_R15.fbx` | The model to import. It has a Roblox R15 skeleton, 15 body parts and built-in textures. |
| `Jax_ALB/NOR/RGH/MTL.png` | Color, surface detail, roughness and metal maps. They are already inside the FBX, and are here as backups. |
| `Jax_Mercer.blend` | The Blender file, if you ever want to edit Jax. |
| `previews/` | Rendered pictures of Jax, plus a walking-pose test of the rig. |
