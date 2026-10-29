package maeiro.viewpointextractionsupport;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

public final class ExtractionRope {
    private static final float STOREY_METRES = 2.4494896f;
    private static final int SEGMENTS = 18;
    private static final int RENDER_SUBDIVISIONS = 3;
    private static final int COIL_SEGMENTS = 24;
    private static final int MAX_ROPES = 3;
    private static final float ROPE_SLACK = 1.0f;
    private static final float GROUND_GAP = 0.70f;
    private static final Rope[] EMPTY = new Rope[0];
    private static final ArrayList<Rope> pending = new ArrayList<>();
    // Viewpoint rotates three scene buffers; rope physics must share one timeline across them.
    private static final Map<String, State> states = new ConcurrentHashMap<>();
    private static volatile Rope[] ropes = EMPTY;
    private static Field camX, camY, camZ, scene, windX, windZ;
    private static float modelLift = -0.1f;
    private static boolean failed;

    private record Rope(String id, float x, float y, float groundX, float groundY,
            float ground, float height, float progress, float alpha) {
    }

    private static final class State {
        final float[] x = new float[SEGMENTS + 1];
        final float[] y = new float[SEGMENTS + 1];
        final float[] z = new float[SEGMENTS + 1];
        final float[] previousX = new float[SEGMENTS + 1];
        final float[] previousY = new float[SEGMENTS + 1];
        final float[] previousZ = new float[SEGMENTS + 1];
        final float[] visualX = new float[SEGMENTS + 1];
        final float[] visualY = new float[SEGMENTS + 1];
        final float[] visualZ = new float[SEGMENTS + 1];
        float length;
        long updatedAt;
        boolean initialized;
    }

    private ExtractionRope() {
    }

    public static void begin() {
        pending.clear();
    }

    public static void add(String id, double x, double y, double groundX, double groundY, double ground,
            double height, double progress, double alpha) {
        if (id == null || id.isBlank() || id.length() > 180 || pending.size() >= 32
                || !finite(x) || !finite(y) || !finite(groundX) || !finite(groundY)
                || !finite(ground) || !finite(height)
                || Math.abs(x) >= 10000000 || Math.abs(y) >= 10000000
                || Math.abs(groundX) >= 10000000 || Math.abs(groundY) >= 10000000
                || height - ground < 2 || height - ground > 80
                || !finite(progress) || progress < 0 || progress > 1
                || !finite(alpha) || alpha <= 0 || alpha > 1) return;
        pending.add(new Rope(id, (float) x, (float) y, (float) groundX, (float) groundY,
                (float) ground, (float) height, (float) progress, (float) alpha));
    }

    public static void end() {
        ropes = pending.toArray(EMPTY);
    }

    public static void clear() {
        pending.clear();
        ropes = EMPTY;
        states.clear();
        RopeRenderer.clear();
    }

    public static void capture(Object frame) {
        Rope[] snapshot = ropes;
        if (snapshot.length == 0) {
            states.clear();
            if (frame != null && scene != null) {
                try {
                    Object sceneData = scene.get(frame);
                    RopeRenderer.clear(sceneData);
                } catch (IllegalAccessException ignored) {
                }
            }
            return;
        }
        if (frame == null || failed) return;
        try {
            if (scene == null) initialize(frame);

            float cameraX = camX.getFloat(frame);
            float cameraY = camY.getFloat(frame);
            float cameraZ = camZ.getFloat(frame) * STOREY_METRES;
            Object sceneData = scene.get(frame);
            float windXValue = windX.getFloat(sceneData);
            float windZValue = windZ.getFloat(sceneData);
            RopeRenderer.MeshBuilder mesh = new RopeRenderer.MeshBuilder();
            long now = System.nanoTime();
            Set<String> activeIds = new HashSet<>();

            ArrayList<Rope> ordered = new ArrayList<>(snapshot.length);
            for (Rope rope : snapshot) ordered.add(rope);
            ordered.sort((first, second) -> Float.compare(
                    distanceSquared(first, cameraX, cameraY), distanceSquared(second, cameraX, cameraY)));

            int count = Math.min(MAX_ROPES, ordered.size());
            for (int index = 0; index < count; index++) {
                Rope rope = ordered.get(index);
                activeIds.add(rope.id);
                if (distanceSquared(rope, cameraX, cameraY) > 10000) continue;
                float groundZ = rope.ground;
                float topZ = rope.height + modelLift - 0.1f;
                float horizontalX = rope.x - rope.groundX;
                float horizontalY = rope.y - rope.groundY;
                float verticalDistance = topZ - (groundZ + GROUND_GAP);
                if (verticalDistance <= 1 || verticalDistance > 80) continue;
                float fullLength = (float) Math.sqrt(horizontalX * horizontalX + horizontalY * horizontalY
                        + verticalDistance * verticalDistance) * ROPE_SLACK;

                appendCoil(mesh, rope, topZ, cameraX, cameraY, cameraZ);
                float length = fullLength * rope.progress;
                if (length < 0.08f) continue;
                State state = states.computeIfAbsent(rope.id, ignored -> new State());
                advance(state, rope.x, rope.y, topZ, rope.groundX, rope.groundY,
                        groundZ, length, windXValue, windZValue, now);
                appendRope(mesh, state.visualX, state.visualY, state.visualZ,
                        groundZ + GROUND_GAP, cameraX, cameraY, cameraZ);
            }
            states.keySet().removeIf(idValue -> !activeIds.contains(idValue));
            RopeRenderer.capture(sceneData, mesh.toArray());
        } catch (ReflectiveOperationException | RuntimeException error) {
            failed = true;
            System.err.println("[Viewpoint Extraction Support] Extraction rope rendering unavailable: " + error);
        }
    }

    private static boolean finite(double value) {
        return Double.isFinite(value);
    }

    private static float distanceSquared(Rope rope, float x, float y) {
        float dx = rope.x - x, dy = rope.y - y;
        return dx * dx + dy * dy;
    }

    private static void advance(State state, float anchorX, float anchorY, float anchorZ,
            float groundX, float groundY, float groundZ, float length,
            float windXValue, float windZValue, long now) {
        if (!state.initialized || state.length <= 0) {
            for (int point = 0; point <= SEGMENTS; point++) {
                float ratio = point / (float) SEGMENTS;
                state.x[point] = state.previousX[point] = anchorX + (groundX - anchorX) * ratio;
                state.y[point] = state.previousY[point] = anchorY + (groundY - anchorY) * ratio;
                state.z[point] = state.previousZ[point] = anchorZ - length * ratio;
                state.visualX[point] = state.x[point];
                state.visualY[point] = state.y[point];
                state.visualZ[point] = state.z[point];
            }
            state.length = length;
            state.updatedAt = now;
            state.initialized = true;
        }

        float dt = Math.min(0.05f, Math.max(0, (now - state.updatedAt) / 1_000_000_000f));
        float lengthChange = length - state.length;
        for (int point = 1; point <= SEGMENTS; point++) {
            float ratio = point / (float) SEGMENTS;
            state.z[point] -= lengthChange * ratio;
            state.previousZ[point] -= lengthChange * ratio;
        }
        state.length = length;
        state.updatedAt = now;
        state.x[0] = state.previousX[0] = anchorX;
        state.y[0] = state.previousY[0] = anchorY;
        state.z[0] = state.previousZ[0] = anchorZ;

        if (dt > 0) {
            float windX = clamp(windXValue, -1, 1) * 0.35f;
            float windY = clamp(windZValue, -1, 1) * 0.35f;
            float dtSquared = dt * dt;
            for (int point = 1; point <= SEGMENTS; point++) {
                float currentX = state.x[point], currentY = state.y[point], currentZ = state.z[point];
                float velocityX = (currentX - state.previousX[point]) * 0.85f;
                float velocityY = (currentY - state.previousY[point]) * 0.85f;
                float velocityZ = (currentZ - state.previousZ[point]) * 0.85f;
                state.previousX[point] = currentX;
                state.previousY[point] = currentY;
                state.previousZ[point] = currentZ;
                state.x[point] = currentX + velocityX + windX * dtSquared;
                state.y[point] = currentY + velocityY + windY * dtSquared;
                state.z[point] = currentZ + velocityZ - 9.81f * dtSquared;
            }
        }

        float bottomZ = groundZ + GROUND_GAP;
        float segmentLength = length / SEGMENTS;
        for (int iteration = 0; iteration < 12; iteration++) {
            state.x[0] = anchorX;
            state.y[0] = anchorY;
            state.z[0] = anchorZ;
            for (int point = 0; point < SEGMENTS; point++) {
                int next = point + 1;
                float dx = state.x[next] - state.x[point];
                float dy = state.y[next] - state.y[point];
                float dz = state.z[next] - state.z[point];
                float distance = (float) Math.sqrt(dx * dx + dy * dy + dz * dz);
                if (distance < 0.0001f) continue;
                float correction = (distance - segmentLength) / distance;
                float cx = dx * correction, cy = dy * correction, cz = dz * correction;
                if (point == 0) {
                    state.x[next] -= cx;
                    state.y[next] -= cy;
                    state.z[next] -= cz;
                } else {
                    state.x[point] += cx * 0.5f;
                    state.y[point] += cy * 0.5f;
                    state.z[point] += cz * 0.5f;
                    state.x[next] -= cx * 0.5f;
                    state.y[next] -= cy * 0.5f;
                    state.z[next] -= cz * 0.5f;
                }
            }
            for (int point = 1; point <= SEGMENTS; point++) {
                if (state.z[point] < bottomZ) {
                    state.z[point] = bottomZ;
                }
            }
        }
        state.x[0] = anchorX;
        state.y[0] = anchorY;
        state.z[0] = anchorZ;
        state.previousX[0] = anchorX;
        state.previousY[0] = anchorY;
        state.previousZ[0] = anchorZ;
        for (int point = 1; point <= SEGMENTS; point++) {
            if (state.z[point] <= bottomZ + 0.06f) {
                state.z[point] = bottomZ;
                state.previousZ[point] = bottomZ;
                state.previousX[point] = state.x[point] - (state.x[point] - state.previousX[point]) * 0.45f;
                state.previousY[point] = state.y[point] - (state.y[point] - state.previousY[point]) * 0.45f;
            }
        }
        float blend = dt <= 0 ? 1 : 1 - (float) Math.exp(-dt * 16);
        for (int point = 0; point <= SEGMENTS; point++) {
            state.visualX[point] += (state.x[point] - state.visualX[point]) * blend;
            state.visualY[point] += (state.y[point] - state.visualY[point]) * blend;
            state.visualZ[point] += (state.z[point] - state.visualZ[point]) * blend;
            if (point > 0) state.visualZ[point] = Math.max(bottomZ, state.visualZ[point]);
        }
    }

    private static float clamp(float value, float low, float high) {
        return Math.max(low, Math.min(high, value));
    }

    private static void appendCoil(RopeRenderer.MeshBuilder mesh, Rope rope, float topZ,
            float cameraX, float cameraY, float cameraZ) {
        float alpha = rope.alpha * (1 - rope.progress);
        if (alpha < 0.025f) return;
        float[][] points = new float[COIL_SEGMENTS + 1][3];
        for (int point = 0; point <= COIL_SEGMENTS; point++) {
            float ratio = point / (float) COIL_SEGMENTS;
            double angle = ratio * Math.PI * 6;
            points[point][0] = rope.x + (float) Math.cos(angle) * 0.12f;
            points[point][1] = rope.y + (float) Math.sin(angle) * 0.12f;
            points[point][2] = topZ - 0.08f - ratio * 0.2f;
        }
        appendLines(mesh, points, points.length, alpha, cameraX, cameraY, cameraZ);
    }

    private static void appendLines(RopeRenderer.MeshBuilder mesh, float[] x, float[] y, float[] z, int count,
            float alpha, float cameraX, float cameraY, float cameraZ) {
        for (int point = 0; point < count - 1; point++) {
            mesh.addSegment(x[point], y[point], z[point], x[point + 1], y[point + 1], z[point + 1],
                    cameraX, cameraY, cameraZ, alpha, point > 0, point < count - 2);
        }
    }

    private static void appendRope(RopeRenderer.MeshBuilder mesh, float[] pointsX, float[] pointsY,
            float[] thisZ, float floorZ,
            float cameraX, float cameraY, float cameraZ) {
        for (int segment = 0; segment < SEGMENTS; segment++) {
            int p0 = Math.max(0, segment - 1);
            int p1 = segment;
            int p2 = segment + 1;
            int p3 = Math.min(SEGMENTS, segment + 2);
            float previousX = pointsX[p1];
            float previousY = pointsY[p1];
            float previousZ = Math.max(floorZ, thisZ[p1]);

            for (int subdivision = 1; subdivision <= RENDER_SUBDIVISIONS; subdivision++) {
                float t = subdivision / (float) RENDER_SUBDIVISIONS;
                float nextX = catmullRom(pointsX[p0], pointsX[p1], pointsX[p2], pointsX[p3], t);
                float nextY = catmullRom(pointsY[p0], pointsY[p1], pointsY[p2], pointsY[p3], t);
                float z = Math.max(floorZ,
                        catmullRom(thisZ[p0], thisZ[p1], thisZ[p2], thisZ[p3], t));
                boolean extendStart = segment > 0 || subdivision > 1;
                boolean extendEnd = segment < SEGMENTS - 1 || subdivision < RENDER_SUBDIVISIONS;
                mesh.addSegment(previousX, previousY, previousZ, nextX, nextY, z,
                        cameraX, cameraY, cameraZ, 1.0f, extendStart, extendEnd);
                previousX = nextX;
                previousY = nextY;
                previousZ = z;
            }
        }
    }

    private static float catmullRom(float p0, float p1, float p2, float p3, float t) {
        float t2 = t * t;
        float t3 = t2 * t;
        return 0.5f * ((2 * p1) + (-p0 + p2) * t
                + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
    }

    private static void appendLines(RopeRenderer.MeshBuilder mesh, float[][] points, int count,
            float alpha, float cameraX, float cameraY, float cameraZ) {
        for (int point = 0; point < count - 1; point++) {
            float[] start = points[point];
            float[] end = points[point + 1];
            mesh.addSegment(start[0], start[1], start[2], end[0], end[1], end[2],
                    cameraX, cameraY, cameraZ, alpha, point > 0, point < count - 2);
        }
    }

    private static void initialize(Object frame) throws ReflectiveOperationException {
        Class<?> frameType = frame.getClass();
        camX = frameType.getField("camX");
        camY = frameType.getField("camY");
        camZ = frameType.getField("camZ");
        scene = frameType.getField("scene");
        Class<?> sceneType = scene.getType();
        windX = sceneType.getField("windX");
        windZ = sceneType.getField("windZ");

        try {
            Class<?> catalog = Class.forName("visiblehelicopter.AircraftCatalog");
            int index = ((Number) catalog.getMethod("index", String.class).invoke(null, "UH-1BHelicopter")).intValue();
            Object[] aircraft = (Object[]) catalog.getField("ALL").get(null);
            if (index >= 0 && index < aircraft.length) {
                modelLift = ((Number) aircraft[index].getClass().getMethod("lift").invoke(aircraft[index])).floatValue();
            }
        } catch (ReflectiveOperationException | RuntimeException ignored) {
            modelLift = -0.1f;
        }
    }
}
