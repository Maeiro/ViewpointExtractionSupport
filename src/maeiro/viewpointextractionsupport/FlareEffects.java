package maeiro.viewpointextractionsupport;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;

public final class FlareEffects {
    private static final float STOREY_METRES = 2.4494896f;
    private static final Flare[] EMPTY = new Flare[0];
    private static final ArrayList<Flare> pending = new ArrayList<>();
    private static volatile Flare[] flares = EMPTY;
    private static Field camX, camY, camZ, scene, flames, relief;
    private static Method reliefHeight;
    private static Method getTexture, ready, xStart, yStart, xEnd, yEnd, full, add;
    private static Object glow, smoke;
    private static boolean failed;

    private record Flare(float x, float y, float z, float dx, float dy, float age) {
    }

    private FlareEffects() {
    }

    public static void begin() {
        pending.clear();
    }

    public static void add(double x, double y, double z, double dx, double dy, double age) {
        if (pending.size() >= 8 || !Double.isFinite(x) || !Double.isFinite(y) || !Double.isFinite(z)
                || !Double.isFinite(dx) || !Double.isFinite(dy) || !Double.isFinite(age)
                || Math.abs(x) > 10000000 || Math.abs(y) > 10000000 || z < -32 || z > 255
                || age < 0 || age >= 20) return;
        double length = Math.hypot(dx, dy);
        if (length < 0.001) return;
        pending.add(new Flare((float) x, (float) y, (float) z,
                (float) (dx / length), (float) (dy / length), (float) age));
    }

    public static void end() {
        flares = pending.toArray(EMPTY);
    }

    public static void clear() {
        pending.clear();
        flares = EMPTY;
    }

    static float height(float age) {
        float launch = Math.min(age, 2);
        return 1.3f + 14 * launch - 3 * launch * launch - 0.45f * Math.max(0, age - 2);
    }

    static float travel(float age) {
        return 0.45f + 3 * Math.min(age, 2) + 0.15f * Math.max(0, age - 2);
    }

    public static void capture(Object frame) {
        Flare[] snapshot = flares;
        if (failed || frame == null || snapshot.length == 0) return;
        try {
            if (add == null) initialize(frame);
            if (glow == null) glow = getTexture.invoke(null, "media/textures/ViewpointExtractionSupport_FlareGlow.png");
            if (smoke == null) smoke = getTexture.invoke(null, "media/textures/ViewpointExtractionSupport_FlareSmoke.png");
            if (glow == null || smoke == null || !Boolean.TRUE.equals(ready.invoke(glow))
                    || !Boolean.TRUE.equals(ready.invoke(smoke))) return;
            float cameraX = camX.getFloat(frame), cameraY = camY.getFloat(frame), cameraZ = camZ.getFloat(frame);
            Object sceneData = scene.get(frame);
            Object batch = flames.get(sceneData);
            Object terrain = relief == null ? null : relief.get(sceneData);
            for (Flare flare : snapshot) {
                if (Math.hypot(flare.x - cameraX, flare.y - cameraY) > 150) continue;
                float age = flare.age;
                float fade = Math.min(1, (20 - age) / 4);
                float ground = terrain == null ? 0 : ((Number) reliefHeight.invoke(terrain, flare.x, flare.y)).floatValue();
                float x = cameraX - flare.x - flare.dx * travel(age);
                float y = (flare.z - cameraZ) * STOREY_METRES + ground + height(age);
                float z = cameraY - flare.y - flare.dy * travel(age);
                float pulse = 0.95f + 0.05f * (float) Math.sin(age * 17);
                if (!card(batch, glow, x, y, z, 1.6f, 1, 0.015f, 0.005f, fade * 0.65f, true)
                        || !card(batch, glow, x, y, z, 0.55f * pulse, 1.8f, 0.1f, 0.02f, fade, true)
                        || !card(batch, glow, x, y, z, 0.15f, 2, 1.1f, 0.7f, fade, true)) return;
                for (int index = 1; index <= 10; index++) {
                    float sampleAge = age - index * 0.2f;
                    if (sampleAge < 0) break;
                    float tail = index / 10f;
                    float drift = (float) Math.sin(sampleAge * 2.4f) * tail * 0.18f;
                    float sx = cameraX - flare.x - flare.dx * travel(sampleAge) + drift;
                    float sy = (flare.z - cameraZ) * STOREY_METRES + ground + height(sampleAge) + tail * 0.5f;
                    float sz = cameraY - flare.y - flare.dy * travel(sampleAge);
                    if (!card(batch, smoke, sx, sy, sz, 0.35f + tail * 1.1f,
                            1, 0.06f, 0.025f, fade * (1 - tail * 0.8f) * 0.65f, false)) return;
                }
            }
        } catch (ReflectiveOperationException | RuntimeException error) {
            failed = true;
            System.err.println("[Viewpoint Extraction Support] Flare rendering unavailable: " + error);
        }
    }

    private static boolean card(Object batch, Object texture, float x, float y, float z, float size,
            float red, float green, float blue, float alpha, boolean emissive) throws ReflectiveOperationException {
        if (Boolean.TRUE.equals(full.invoke(batch))) return false;
        float[] uv = { ((Number) xStart.invoke(texture)).floatValue(), ((Number) yStart.invoke(texture)).floatValue(),
                ((Number) xEnd.invoke(texture)).floatValue(), ((Number) yEnd.invoke(texture)).floatValue() };
        float half = size / 2;
        add.invoke(batch, texture, uv, new float[] { x, y, z },
                new float[] { -half, -half, half, half }, 0f, new float[] { red, green, blue, alpha }, emissive);
        return true;
    }

    private static void initialize(Object frame) throws ReflectiveOperationException {
        Class<?> type = frame.getClass();
        camX = type.getField("camX");
        camY = type.getField("camY");
        camZ = type.getField("camZ");
        scene = type.getField("scene");
        flames = scene.getType().getField("flames");
        try {
            Field terrain = scene.getType().getField("relief");
            reliefHeight = terrain.getType().getMethod("scene", float.class, float.class);
            relief = terrain;
        } catch (NoSuchFieldException | NoSuchMethodException ignored) {
            relief = null;
        }
        Class<?> texture = Class.forName("zombie.core.textures.Texture");
        getTexture = texture.getMethod("getSharedTexture", String.class);
        ready = texture.getMethod("isReady");
        xStart = texture.getMethod("getXStart");
        yStart = texture.getMethod("getYStart");
        xEnd = texture.getMethod("getXEnd");
        yEnd = texture.getMethod("getYEnd");
        Class<?> batch = flames.getType();
        full = batch.getMethod("full");
        add = batch.getMethod("add", texture, float[].class, float[].class, float[].class,
                float.class, float[].class, boolean.class);
    }
}
