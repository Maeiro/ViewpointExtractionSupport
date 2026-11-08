# Extraction flare gun

Original: **Flare Gun**, Quaternius, Survival Pack.

- Model page and license: https://poly.pizza/m/44H9OBUqTC
- Original GLB download: https://static.poly.pizza/9ec52cda-c918-43f0-b7af-354e7fe96c37.glb
- License: **CC0 1.0 Universal**, https://creativecommons.org/publicdomain/zero/1.0/

The included `Quaternius-FlareGun.glb` is the source model. The game mesh is converted to DirectX `.x`, aligned with Zomboid's handgun axes and scaled to 28 cm. The two material colors are baked into a small palette texture. The inventory icon is rendered from this mesh. Rebuild these assets with `py tools/build_flare_assets.py` (NumPy and Pillow).

The glow and smoke textures are generated procedurally by the same script and are original to this addon.
