# Extraction rope prototype

Procedurally generated 3D rope concept for Viewpoint Extraction Support. The geometry is authored in this repository; it does not reuse third-party mod assets.

## Files

- `rope_stowed.glb` / `.obj`: compact rope bundle near the helicopter attachment point.
- `rope_deployed.glb` / `.obj`: 12 m hanging rope with a slight static sway and a lower eye.
- `preview.png`: comparison render, including a zoomed braid detail.
- `generate_rope.py`: source generator and GLB/OBJ exporter.

The stowed and deployed meshes are static visual poses. They do not contain animation or runtime physics. The deployed mesh is about 21,000 triangles; the stowed mesh is about 11,000. In-game integration would need to attach the model to the helicopter renderer and animate or simulate its length separately. Compatibility with the current Project Viewpoint / Visible Helicopter Events model pipeline has not yet been tested.
