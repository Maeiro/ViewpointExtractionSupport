from __future__ import annotations

import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
MATERIALS = {
    "hemp_light": (0.72, 0.67, 0.51),
    "hemp_mid": (0.57, 0.58, 0.43),
    "hemp_dark": (0.42, 0.47, 0.35),
    "hardware": (0.22, 0.26, 0.28),
    "hardware_edge": (0.48, 0.49, 0.45),
}


class Mesh:
    def __init__(self):
        self.vertices: list[tuple[float, float, float]] = []
        self.faces: list[tuple[str, tuple[int, int, int]]] = []

    def add_tube(self, path, radius, sides, material, closed=False):
        points = np.asarray(path, dtype=np.float64)
        if len(points) < 2:
            return
        tangents = np.empty_like(points)
        tangents[0] = points[1] - points[0]
        tangents[-1] = points[-1] - points[-2]
        if closed:
            tangents[0] = points[1] - points[-2]
            tangents[-1] = points[1] - points[-2]
        if len(points) > 2:
            tangents[1:-1] = points[2:] - points[:-2]
        tangents /= np.maximum(np.linalg.norm(tangents, axis=1, keepdims=True), 1e-9)

        rings = []
        for point, tangent in zip(points, tangents):
            ref = np.array((0.0, 1.0, 0.0)) if abs(tangent[2]) > 0.9 else np.array((0.0, 0.0, 1.0))
            normal = np.cross(tangent, ref)
            normal /= max(np.linalg.norm(normal), 1e-9)
            binormal = np.cross(tangent, normal)
            ring = []
            for side in range(sides):
                angle = 2 * math.pi * side / sides
                vertex = point + radius * (math.cos(angle) * normal + math.sin(angle) * binormal)
                ring.append(len(self.vertices))
                self.vertices.append(tuple(float(value) for value in vertex))
            rings.append(ring)

        pair_count = len(rings) if closed else len(rings) - 1
        for index in range(pair_count):
            current = rings[index]
            following = rings[(index + 1) % len(rings)]
            for side in range(sides):
                a, b = current[side], current[(side + 1) % sides]
                c, d = following[(side + 1) % sides], following[side]
                self.faces.append((material, (a, b, c)))
                self.faces.append((material, (a, c, d)))

    def add_rope(self, centerline, twist_turns, material_cycle=True):
        centerline = np.asarray(centerline, dtype=np.float64)
        count = len(centerline)
        tangents = np.empty_like(centerline)
        tangents[0] = centerline[1] - centerline[0]
        tangents[-1] = centerline[-1] - centerline[-2]
        tangents[1:-1] = centerline[2:] - centerline[:-2]
        tangents /= np.maximum(np.linalg.norm(tangents, axis=1, keepdims=True), 1e-9)
        materials = ("hemp_light", "hemp_mid", "hemp_dark")
        strand_offset = 0.0105
        strand_radius = 0.009
        for strand in range(3):
            strand_path = []
            phase_offset = strand * 2 * math.pi / 3
            for index, (point, tangent) in enumerate(zip(centerline, tangents)):
                ref = np.array((0.0, 1.0, 0.0)) if abs(tangent[2]) > 0.9 else np.array((0.0, 0.0, 1.0))
                normal = np.cross(tangent, ref)
                normal /= max(np.linalg.norm(normal), 1e-9)
                binormal = np.cross(tangent, normal)
                phase = 2 * math.pi * twist_turns * index / (count - 1) + phase_offset
                strand_path.append(point + strand_offset * (math.cos(phase) * normal + math.sin(phase) * binormal))
            self.add_tube(strand_path, strand_radius, 6, materials[strand], closed=False)

    def add_cylinder(self, center, radius, depth, material, sides=12):
        cx, cy, cz = center
        low, high = cz - depth / 2, cz + depth / 2
        lower, upper = [], []
        for index in range(sides):
            angle = 2 * math.pi * index / sides
            x, y = cx + math.cos(angle) * radius, cy + math.sin(angle) * radius
            lower.append(len(self.vertices)); self.vertices.append((x, y, low))
            upper.append(len(self.vertices)); self.vertices.append((x, y, high))
        for index in range(sides):
            nxt = (index + 1) % sides
            self.faces.extend([
                (material, (lower[index], lower[nxt], upper[nxt])),
                (material, (lower[index], upper[nxt], upper[index])),
            ])

    def add_torus(self, center, major_radius, minor_radius, material, plane="xz", major_steps=20, minor_steps=5):
        cx, cy, cz = center
        path = []
        for index in range(major_steps):
            angle = 2 * math.pi * index / major_steps
            if plane == "xz":
                path.append((cx + major_radius * math.cos(angle), cy, cz + major_radius * math.sin(angle)))
            else:
                path.append((cx + major_radius * math.cos(angle), cy + major_radius * math.sin(angle), cz))
        self.add_tube(path, minor_radius, minor_steps, material, closed=True)

    def bounds(self):
        vertices = np.asarray(self.vertices)
        return vertices.min(axis=0), vertices.max(axis=0)

    def triangle_count(self):
        return len(self.faces)


def circle_path(radius, z, steps=96, center=(0.0, 0.0)):
    return [(center[0] + radius * math.cos(2 * math.pi * i / steps),
             center[1] + radius * math.sin(2 * math.pi * i / steps), z)
            for i in range(steps + 1)]


def add_collar(mesh):
    mesh.add_cylinder((0, 0, -0.035), 0.019, 0.018, "hardware", 10)
    mesh.add_cylinder((0, 0, -0.024), 0.023, 0.007, "hardware_edge", 10)
    mesh.add_torus((0, 0, -0.058), 0.016, 0.0035, "hardware", "xz", 16, 4)


def make_stowed():
    mesh = Mesh()
    add_collar(mesh)
    for layer in range(3):
        z = -0.105 - layer * 0.018
        for center_x in (-0.075, 0.075):
            path = circle_path(0.082, z, 48, (center_x, 0.0))
            mesh.add_rope(path, 2.0)
    tail = [(0.157, 0.0, -0.14), (0.15, -0.02, -0.22),
            (0.10, -0.02, -0.30), (0.05, -0.01, -0.36)]
    mesh.add_rope(tail, 1.0)
    return mesh


def make_detail():
    mesh = Mesh()
    points = []
    for index in range(97):
        t = index / 96
        points.append((0.018 * math.sin(t * math.pi * 2), 0.012 * math.sin(t * math.pi), -0.02 - 0.45 * t))
    mesh.add_rope(points, 3.2)
    mesh.add_torus((points[-1][0], points[-1][1], -0.52), 0.026, 0.0045, "hardware_edge", "xz", 20, 5)
    return mesh


def make_deployed():
    mesh = Mesh()
    add_collar(mesh)
    partial_coil = []
    turns = 1.15
    for index in range(100):
        t = index / 99
        angle = turns * 2 * math.pi * t
        radius = 0.092 + 0.008 * math.sin(math.pi * t)
        partial_coil.append((radius * math.cos(angle), radius * math.sin(angle), -0.095 - 0.075 * t))
    mesh.add_rope(partial_coil, turns * 2.1)

    length = 11.65
    steps = 480
    line = []
    for index in range(steps + 1):
        t = index / steps
        x = 0.035 * math.sin(t * math.pi * 2.2) + 0.018 * math.sin(t * math.pi * 5.0)
        y = 0.025 * math.sin(t * math.pi * 1.4)
        z = -0.15 - length * t
        line.append((x, y, z))
    mesh.add_rope(line, 72)
    end_z = -0.15 - length
    mesh.add_torus((line[-1][0], line[-1][1], end_z - 0.055), 0.032, 0.005, "hardware_edge", "xz", 20, 5)
    mesh.add_cylinder((line[-1][0], line[-1][1], end_z - 0.008), 0.022, 0.035, "hardware", 10)
    return mesh


def export_obj(mesh, stem):
    path = OUT / f"{stem}.obj"
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(f"mtllib {stem}.mtl\n")
        for vertex in mesh.vertices:
            handle.write("v %.6f %.6f %.6f\n" % vertex)
        current = None
        for material, face in mesh.faces:
            if current != material:
                handle.write(f"usemtl {material}\n")
                current = material
            handle.write("f %d %d %d\n" % (face[0] + 1, face[1] + 1, face[2] + 1))
    with (OUT / f"{stem}.mtl").open("w", encoding="utf-8", newline="\n") as handle:
        for material, color in MATERIALS.items():
            handle.write(f"newmtl {material}\nKd {color[0]:.4f} {color[1]:.4f} {color[2]:.4f}\nKa 0.08 0.08 0.08\nKs 0.05 0.05 0.05\nNs 8\n\n")
    return path


def export_glb(mesh, stem):
    positions = np.asarray(mesh.vertices, dtype="<f4")
    normals = np.zeros_like(positions)
    groups = {name: [] for name in MATERIALS}
    for material, face in mesh.faces:
        a, b, c = (positions[index].astype(np.float64) for index in face)
        normal = np.cross(b - a, c - a)
        length = np.linalg.norm(normal)
        if length > 1e-10:
            normal /= length
            for index in face:
                normals[index] += normal
        groups[material].extend(face)
    lengths = np.linalg.norm(normals, axis=1)
    normals /= np.maximum(lengths[:, None], 1e-9)
    normals = normals.astype("<f4")

    binary = bytearray()
    buffer_views = []
    accessors = []

    def add_view(data, target=None):
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        binary.extend(data)
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        if target:
            view["target"] = target
        buffer_views.append(view)
        return len(buffer_views) - 1

    position_view = add_view(positions.tobytes(), 34962)
    position_min = positions.min(axis=0).tolist()
    position_max = positions.max(axis=0).tolist()
    accessors.append({"bufferView": position_view, "componentType": 5126, "count": len(positions), "type": "VEC3", "min": position_min, "max": position_max})
    normal_view = add_view(normals.tobytes(), 34962)
    accessors.append({"bufferView": normal_view, "componentType": 5126, "count": len(normals), "type": "VEC3"})

    primitives = []
    for material_index, material in enumerate(MATERIALS):
        indices = groups[material]
        if not indices:
            continue
        index_data = np.asarray(indices, dtype="<u4").tobytes()
        index_view = add_view(index_data, 34963)
        accessor_index = len(accessors)
        accessors.append({"bufferView": index_view, "componentType": 5125, "count": len(indices), "type": "SCALAR", "min": [min(indices)], "max": [max(indices)]})
        primitives.append({"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": accessor_index, "material": material_index, "mode": 4})

    gltf = {
        "asset": {"version": "2.0", "generator": "Viewpoint Extraction Support rope prototype"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": stem}],
        "meshes": [{"name": stem, "primitives": primitives}],
        "materials": [{"name": name, "pbrMetallicRoughness": {"baseColorFactor": [*color, 1.0], "metallicFactor": 0.28 if "hardware" in name else 0.0, "roughnessFactor": 0.82}} for name, color in MATERIALS.items()],
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": buffer_views,
        "accessors": accessors,
    }
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(json_bytes) % 4:
        json_bytes += b" "
    while len(binary) % 4:
        binary.append(0)
    total_length = 12 + 8 + len(json_bytes) + 8 + len(binary)
    output = bytearray(struct.pack("<4sII", b"glTF", 2, total_length))
    output.extend(struct.pack("<I4s", len(json_bytes), b"JSON")); output.extend(json_bytes)
    output.extend(struct.pack("<I4s", len(binary), b"BIN\x00")); output.extend(binary)
    path = OUT / f"{stem}.glb"
    path.write_bytes(output)
    return path


def render_preview(stowed, deployed):
    width, height = 1500, 920
    image = Image.new("RGB", (width, height), (23, 27, 33))
    draw = ImageDraw.Draw(image)
    try:
        title_font = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 27)
        label_font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 18)
        small_font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 14)
    except OSError:
        title_font = label_font = small_font = ImageFont.load_default()

    panels = [(44, 92, 706, 858), (738, 92, 1456, 858)]
    for x1, y1, x2, y2 in panels:
        draw.rounded_rectangle((x1, y1, x2, y2), 16, fill=(30, 35, 42), outline=(61, 70, 80), width=2)
    draw.text((48, 28), "EXTRACTION ROPE — 3D PROTOTYPE", font=title_font, fill=(232, 237, 240))
    draw.text((panels[0][0] + 22, panels[0][1] + 18), "STOWED", font=label_font, fill=(198, 213, 222))
    draw.text((panels[1][0] + 22, panels[1][1] + 18), "DEPLOYED", font=label_font, fill=(198, 213, 222))

    def render(mesh, viewport, target, scale, translate=(0, 0, 0), floor_z=None):
        x1, y1, x2, y2 = viewport
        cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        cam = np.array((5.4, -18.0, -4.2), dtype=np.float64)
        look = np.array((0.0, 0.0, -5.7 if target == "deployed" else -0.25), dtype=np.float64)
        direction = look - cam
        direction /= np.linalg.norm(direction)
        right = np.cross(direction, np.array((0.0, 0.0, 1.0)))
        right /= np.linalg.norm(right)
        up = np.cross(right, direction)
        up /= np.linalg.norm(up)
        center = np.asarray(translate, dtype=np.float64)
        vertices = np.asarray(mesh.vertices, dtype=np.float64) - center
        camera_coords = np.column_stack((vertices @ right, vertices @ up, vertices @ direction))
        screen = np.column_stack((cx + camera_coords[:, 0] * scale, cy - camera_coords[:, 1] * scale))
        lighting = np.array((0.35, -0.6, 0.72), dtype=np.float64); lighting /= np.linalg.norm(lighting)
        view_width, view_height = int(x2 - x1), int(y2 - y1)
        depth_buffer = np.full((view_height, view_width), np.inf, dtype=np.float32)
        color_buffer = np.zeros((view_height, view_width, 3), dtype=np.uint8)
        for material, face in mesh.faces:
            indices = list(face)
            pts = screen[indices]
            min_x = max(0, int(math.floor(np.min(pts[:, 0]) - x1)))
            max_x = min(view_width - 1, int(math.ceil(np.max(pts[:, 0]) - x1)))
            min_y = max(0, int(math.floor(np.min(pts[:, 1]) - y1)))
            max_y = min(view_height - 1, int(math.ceil(np.max(pts[:, 1]) - y1)))
            if min_x > max_x or min_y > max_y:
                continue
            ax, ay = pts[0, 0] - x1, pts[0, 1] - y1
            bx, by = pts[1, 0] - x1, pts[1, 1] - y1
            cxp, cyp = pts[2, 0] - x1, pts[2, 1] - y1
            denominator = (by - cyp) * (ax - cxp) + (cxp - bx) * (ay - cyp)
            if abs(denominator) < 1e-8:
                continue
            grid_x, grid_y = np.meshgrid(np.arange(min_x, max_x + 1) + 0.5, np.arange(min_y, max_y + 1) + 0.5)
            weight_a = ((by - cyp) * (grid_x - cxp) + (cxp - bx) * (grid_y - cyp)) / denominator
            weight_b = ((cyp - ay) * (grid_x - cxp) + (ax - cxp) * (grid_y - cyp)) / denominator
            weight_c = 1 - weight_a - weight_b
            inside = (weight_a >= -1e-5) & (weight_b >= -1e-5) & (weight_c >= -1e-5)
            depths = weight_a * camera_coords[indices[0], 2] + weight_b * camera_coords[indices[1], 2] + weight_c * camera_coords[indices[2], 2]
            depth_region = depth_buffer[min_y:max_y + 1, min_x:max_x + 1]
            visible = inside & (depths < depth_region)
            if not np.any(visible):
                continue
            a, b, c = vertices[indices]
            normal = np.cross(b - a, c - a)
            normal_length = np.linalg.norm(normal)
            if normal_length < 1e-10:
                continue
            normal /= normal_length
            brightness = 0.65 + 0.35 * abs(float(np.dot(normal, lighting)))
            base = np.asarray(MATERIALS[material])
            color = np.clip(base * brightness * 255, 0, 255).astype(np.uint8)
            depth_region[visible] = depths[visible]
            color_buffer[min_y:max_y + 1, min_x:max_x + 1][visible] = color
        rendered = Image.fromarray(color_buffer, "RGB")
        coverage = Image.fromarray(np.where(np.isfinite(depth_buffer), 255, 0).astype(np.uint8), "L")
        image.paste(rendered, (int(x1), int(y1)), coverage)
        if floor_z is not None:
            world_origin = np.array((0.0, 0.0, floor_z)) - center
            p = (cx + np.dot(world_origin, right) * scale, cy - np.dot(world_origin, up) * scale)
            draw.line((x1 + 35, p[1], x2 - 35, p[1]), fill=(78, 85, 92), width=2)
            for offset in range(-4, 5):
                xx = cx + offset * 0.3 * scale
                draw.line((xx, p[1], xx + 130, p[1] + 70), fill=(45, 51, 58), width=1)

    # Stowed and deployed states are shown at different view scales so the stored coil stays legible.
    render(stowed, panels[0], "stowed", 1450, translate=(0, 0, -0.24))
    render(deployed, (panels[1][0] + 50, panels[1][1] + 76, panels[1][2] - 50, panels[1][3] - 55), "deployed", 60, translate=(0, 0, -5.9), floor_z=-11.95)
    draw.text((panels[0][0] + 22, panels[0][3] - 38), "Compact multi-loop coil · attachment collar", font=small_font, fill=(166, 178, 188))
    inset = (1140, 574, 1428, 817)
    draw.rounded_rectangle(inset, 10, fill=(36, 42, 49), outline=(91, 102, 113), width=2)
    draw.text((inset[0] + 14, inset[1] + 10), "BRAID DETAIL · ZOOM", font=small_font, fill=(206, 216, 224))
    render(make_detail(), (inset[0] + 16, inset[1] + 40, inset[2] - 16, inset[3] - 12), "detail", 360, translate=(0, 0, -0.27))
    draw.text((panels[1][0] + 22, panels[1][3] - 38), "12 m rope · three-strand profile · small lower eye", font=small_font, fill=(166, 178, 188))
    draw.text((48, 882), "Original procedural mesh · two static poses for preview · no runtime physics in this prototype", font=small_font, fill=(145, 156, 166))
    image.save(OUT / "preview.png")


def main():
    stowed = make_stowed()
    deployed = make_deployed()
    for name, mesh in (("rope_stowed", stowed), ("rope_deployed", deployed)):
        export_obj(mesh, name)
        export_glb(mesh, name)
        low, high = mesh.bounds()
        print(f"{name}: {mesh.triangle_count():,} triangles, bounds {np.round(low, 3)} to {np.round(high, 3)}")
    render_preview(stowed, deployed)
    print(f"Preview: {OUT / 'preview.png'}")


if __name__ == "__main__":
    main()
