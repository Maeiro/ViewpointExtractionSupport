"""Convert the CC0 Quaternius flare gun to Zomboid's static .x format."""

import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/flaregun/Quaternius-FlareGun.glb"
MEDIA = ROOT / "42/media"
data = SOURCE.read_bytes()
json_size = struct.unpack_from("<I", data, 12)[0]
document = json.loads(data[20:20 + json_size])
binary = data[28 + json_size:]


def accessor(index):
    value = document["accessors"][index]
    view = document["bufferViews"][value["bufferView"]]
    dtype = {5123: "<u2", 5125: "<u4", 5126: "<f4"}[value["componentType"]]
    width = {"SCALAR": 1, "VEC3": 3}[value["type"]]
    offset = view.get("byteOffset", 0) + value.get("byteOffset", 0)
    return np.frombuffer(binary, dtype=dtype, offset=offset, count=value["count"] * width).reshape(-1, width)


vertices, normals, faces, colors = [], [], [], []
palette = [(205, 66, 29), (45, 43, 40)]
scale = 0.28 / (0.0105061270296574 + 0.0020867430139333)
for primitive in document["meshes"][0]["primitives"]:
    points = accessor(primitive["attributes"]["POSITION"])[:, [1, 0, 2]] * scale
    directions = accessor(primitive["attributes"]["NORMAL"])[:, [1, 0, 2]]
    points[:, 2] *= -1
    directions[:, 2] *= -1
    offset = len(vertices)
    vertices.extend(points)
    normals.extend(directions)
    colors.extend([primitive["material"]] * len(points))
    faces.extend(accessor(primitive["indices"]).reshape(-1, 3) + offset)


def rows(values, formatter):
    return "\n".join(formatter(value) + (";" if i == len(values) - 1 else ",")
                     for i, value in enumerate(values))


face_rows = rows(faces, lambda f: "3;" + ",".join(map(str, f)) + ";")
mesh = "xof 0303txt 0032\nMesh VESExtractionFlareGun {\n"
mesh += f"{len(vertices)};\n" + rows(vertices, lambda v: ";".join(f"{float(x):.8f}" for x in v) + ";")
mesh += f"\n{len(faces)};\n{face_rows}\n"
mesh += f"MeshNormals {{\n{len(normals)};\n"
mesh += rows(normals, lambda v: ";".join(f"{float(x):.7f}" for x in v) + ";")
mesh += f"\n{len(faces)};\n{face_rows}\n}}\n"
mesh += f"MeshTextureCoords {{\n{len(vertices)};\n"
mesh += rows(colors, lambda c: f"{0.25 + c * 0.5:.2f};0.5;") + "\n}\n}\n"
model = MEDIA / "models_X/weapons/VESExtractionFlareGun.x"
model.parent.mkdir(parents=True, exist_ok=True)
model.write_text(mesh, encoding="ascii")

texture = Image.new("RGB", (32, 16), palette[0])
ImageDraw.Draw(texture).rectangle((16, 0, 31, 15), fill=palette[1])
texture_path = MEDIA / "textures/weapons/VESExtractionFlareGun.png"
texture_path.parent.mkdir(parents=True, exist_ok=True)
texture.save(texture_path)

# Render the same mesh for the inventory icon, with a small view onto the barrel.
points = np.array(vertices)
projected = np.column_stack((points[:, 1] + points[:, 0] * 0.7, -points[:, 2] + points[:, 0] * 0.25))
projected -= projected.min(axis=0)
factor = 220 / max(projected.max(axis=0))
projected *= factor
projected[:, 0] += (256 - projected[:, 0].max()) / 2
projected[:, 1] = 230 - projected[:, 1]
icon = Image.new("RGBA", (256, 256))
draw = ImageDraw.Draw(icon)
for face in sorted(faces, key=lambda f: float(points[f, 0].mean()), reverse=True):
    normal = np.array(normals)[face].mean(axis=0)
    shade = 0.6 + 0.4 * abs(float(normal @ np.array([0.7, -0.4, -0.6])))
    color = tuple(min(255, int(channel * shade)) for channel in palette[colors[face[0]]])
    draw.polygon([tuple(projected[v]) for v in face], fill=(*color, 255))
icon = icon.resize((128, 128), Image.Resampling.LANCZOS)
icon.save(MEDIA / "textures/Item_VESExtractionFlareGun.png")
world_icon = MEDIA / "inventory/world/WItem_VESExtractionFlareGun.png"
world_icon.parent.mkdir(parents=True, exist_ok=True)
icon.save(world_icon)

for name, smoke in (("Glow", False), ("Smoke", True)):
    size = 128
    pixels = np.zeros((size, size, 4), dtype=np.uint8)
    for y in range(size):
        for x in range(size):
            dx, dy = (x + 0.5 - size / 2) / (size / 2), (y + 0.5 - size / 2) / (size / 2)
            radius = math.hypot(dx, dy)
            alpha = max(0, 1 - radius) ** (1.6 if smoke else 2.5)
            if smoke:
                alpha *= 0.65 + 0.2 * math.sin(x * 0.18 + math.sin(y * 0.12)) + 0.15 * math.cos(y * 0.25)
            pixels[y, x] = [255, 255, 255, int(max(0, alpha) * 255)]
    image = Image.fromarray(pixels)
    if smoke:
        image = image.filter(ImageFilter.GaussianBlur(1))
    image.save(MEDIA / f"textures/ViewpointExtractionSupport_Flare{name}.png")

print(f"Built flare gun: {len(vertices)} vertices, {len(faces)} triangles, 0.28 m long")
