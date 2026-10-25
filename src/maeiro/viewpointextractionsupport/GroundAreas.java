package maeiro.viewpointextractionsupport;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;

public final class GroundAreas {
    private static final float STOREY_METRES = 2.4494896f;
    private static final int SEGMENTS = 32;
    private static final float HEIGHT = 2.2f;
    private static final Area[] EMPTY = new Area[0];
    private static final ArrayList<Area> pending = new ArrayList<>();
    private static volatile Area[] areas = EMPTY;
    private static volatile Area[] rendered = EMPTY;
    private static Field camX, camY, camZ, scene, blood;
    private static Method getSquare, getFloor, getTexture, ready, textureId, xStart, yStart, xEnd, yEnd, full, draw;
    private static Object markerTexture;
    private static boolean failed;

    private record Area(float x, float y, int z, float radius) {
    }

    private GroundAreas() {
    }

    public static void begin() {
        pending.clear();
    }

    public static void add(double x, double y, double z, double radius) {
        if (pending.size() < 32 && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && Math.abs(x) < 10000000 && Math.abs(y) < 10000000 && z == Math.floor(z) && z >= -32 && z <= 255
                && Double.isFinite(radius) && radius > 0 && radius <= 64) {
            pending.add(new Area((float) x, (float) y, (int) z, (float) radius));
        }
    }

    public static void end() {
        areas = pending.toArray(EMPTY);
    }

    public static void clear() {
        pending.clear();
        areas = EMPTY;
        rendered = EMPTY;
    }

    public static boolean replacesArrow(int x, int y, int z) {
        for (Area area : rendered) {
            if ((int) Math.floor(area.x - 0.5f) == x && (int) Math.floor(area.y - 0.5f) == y && area.z == z) return true;
        }
        return false;
    }

    public static void capture(Object frame, Object cell) {
        Area[] snapshot = areas;
        rendered = EMPTY;
        if (frame == null || cell == null || failed || snapshot.length == 0) return;
        try {
            if (draw == null) initialize(frame, cell);
            if (markerTexture == null) markerTexture = getTexture.invoke(null, "media/textures/ViewpointExtractionSupport_Marker.png");
            if (markerTexture == null || !Boolean.TRUE.equals(ready.invoke(markerTexture))) return;
            float cameraX = camX.getFloat(frame), cameraY = camY.getFloat(frame), cameraZ = camZ.getFloat(frame);
            Object decals = blood.get(scene.get(frame));
            ArrayList<Area> completed = new ArrayList<>();
            for (Area area : snapshot) {
                if (Math.hypot(area.x - cameraX, area.y - cameraY) > 100) continue;
                Object square = getSquare.invoke(cell, (int) Math.floor(area.x), (int) Math.floor(area.y), area.z);
                if (square == null || getFloor.invoke(square) == null) continue;
                boolean complete = true;
                for (int segment = 0; segment < SEGMENTS; segment++) {
                    double a = segment * Math.PI * 2 / SEGMENTS;
                    double b = (segment + 1) * Math.PI * 2 / SEGMENTS;
                    float ax = area.x + (float) Math.cos(a) * area.radius;
                    float ay = area.y + (float) Math.sin(a) * area.radius;
                    float bx = area.x + (float) Math.cos(b) * area.radius;
                    float by = area.y + (float) Math.sin(b) * area.radius;
                    float[] corner = { cameraX - ax, (area.z - cameraZ) * STOREY_METRES + 0.015f, cameraY - ay };
                    float[] sides = { ax - bx, 0, ay - by, 0, HEIGHT, 0 };
                    // The decal shader culls back faces; submit both orientations for views inside the marker.
                    if (!decal(decals, corner, sides, 1) || !decal(decals, corner, sides, -1)) {
                        complete = false;
                        break;
                    }
                }
                if (complete) completed.add(area);
            }
            rendered = completed.toArray(EMPTY);
        } catch (ReflectiveOperationException error) {
            failed = true;
            System.err.println("[Viewpoint Extraction Support] Extraction area rendering unavailable: " + error);
        }
    }

    private static boolean decal(Object decals, float[] corner, float[] sides, float facing)
            throws ReflectiveOperationException {
        if (Boolean.TRUE.equals(full.invoke(decals))) return false;
        int id = ((Number) textureId.invoke(markerTexture)).intValue();
        if (id <= 0) return false;
        float u0 = ((Number) xStart.invoke(markerTexture)).floatValue(), v0 = ((Number) yStart.invoke(markerTexture)).floatValue();
        float u1 = ((Number) xEnd.invoke(markerTexture)).floatValue(), v1 = ((Number) yEnd.invoke(markerTexture)).floatValue();
        float[] uv = { u0, v1, u1 - u0, 0, 0, v0 - v1 };
        float[] rect = { u0, v0, u1, v1 };
        float[] tint = { 1.0f, 0.82f, 0.12f, 0.65f };
        draw.invoke(decals, id, corner, sides, uv, rect, tint, facing);
        return true;
    }

    private static void initialize(Object frame, Object cell) throws ReflectiveOperationException {
        Class<?> type = frame.getClass();
        camX = type.getField("camX");
        camY = type.getField("camY");
        camZ = type.getField("camZ");
        scene = type.getField("scene");
        blood = scene.getType().getField("blood");
        Class<?> square = Class.forName("zombie.iso.IsoGridSquare");
        getSquare = cell.getClass().getMethod("getGridSquare", int.class, int.class, int.class);
        getFloor = square.getMethod("getFloor");
        Class<?> texture = Class.forName("zombie.core.textures.Texture");
        getTexture = texture.getMethod("getSharedTexture", String.class);
        ready = texture.getMethod("isReady");
        textureId = texture.getMethod("getID");
        xStart = texture.getMethod("getXStart");
        yStart = texture.getMethod("getYStart");
        xEnd = texture.getMethod("getXEnd");
        yEnd = texture.getMethod("getYEnd");
        Class<?> batch = blood.getType();
        full = batch.getMethod("full");
        draw = batch.getMethod("add", int.class, float[].class, float[].class, float[].class, float[].class, float[].class, float.class);
    }
}
