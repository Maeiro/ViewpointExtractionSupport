package maeiro.viewpointextractionsupport;

import java.lang.reflect.Field;
import viewpoint.render.FlameDraws;
import zombie.core.textures.Texture;

public final class FlareEffectsTest {
    public static final class Scene {
        public final FlameDraws flames = new FlameDraws();
        public Relief relief = new Relief();
    }

    public static final class Relief {
        public float height;
        public float scene(float x, float y) { return height; }
    }

    public static final class Frame {
        public float camX = 100, camY = 200, camZ = 0;
        public final Scene scene = new Scene();
    }

    private static final Field COUNT;
    private static final Field VALUES;

    static {
        try {
            COUNT = FlameDraws.class.getDeclaredField("count");
            VALUES = FlameDraws.class.getDeclaredField("values");
            COUNT.setAccessible(true);
            VALUES.setAccessible(true);
        } catch (ReflectiveOperationException error) {
            throw new AssertionError(error);
        }
    }

    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    private static void close(float value, float expected, String message) {
        check(Math.abs(value - expected) < 0.001f, message + ": " + value);
    }

    private static int count(Frame frame) throws ReflectiveOperationException {
        return COUNT.getInt(frame.scene.flames);
    }

    public static void main(String[] args) throws ReflectiveOperationException {
        Frame frame = new Frame();
        FlameDraws batch = frame.scene.flames;
        close(FlareEffects.height(0), 1.3f, "launch height");
        close(FlareEffects.height(2), 17.3f, "signal altitude");
        check(FlareEffects.height(19) < FlareEffects.height(2), "signal must descend slowly");

        batch.add(new Texture(), new float[4], new float[] { 77, 88, 99 }, new float[4], 0, new float[4], false);
        FlareEffects.begin();
        FlareEffects.add(100, 200, 2, 2, 0, 5);
        FlareEffects.end();
        FlareEffects.capture(frame);
        check(count(frame) == 14, "one native card plus thirteen signal cards");
        float[] values = (float[]) VALUES.get(batch);
        close(values[0], 77, "native cards must be preserved");
        close(values[20], -FlareEffects.travel(5), "direction must be normalized");
        close(values[21], 2 * 2.4494896f + FlareEffects.height(5), "elevated floor conversion");
        close(values[36], 1, "core must use the native emissive flag");
        close(values[8], 0, "native UVs must stay intact");
        close(values[28], 0.1f, "signal must use the texture's atlas UVs");

        batch.clear();
        frame.scene.relief.height = 3;
        FlareEffects.capture(frame);
        close(values[1], 2 * 2.4494896f + FlareEffects.height(5) + 3, "terrain relief must be included");
        frame.scene.relief = null;
        batch.clear();
        Texture.loaded = false;
        FlareEffects.capture(frame);
        check(count(frame) == 0, "unready textures must be skipped");
        Texture.loaded = true;
        FlareEffects.capture(frame);
        check(count(frame) == 13, "textures must retry when ready");
        batch.clear();
        frame.camX = 500;
        FlareEffects.capture(frame);
        check(count(frame) == 0, "far signals must be skipped");
        frame.camX = 100;

        while (!batch.full()) batch.add(new Texture(), new float[4], new float[3], new float[4], 0, new float[4], false);
        FlareEffects.capture(frame);
        check(count(frame) == 192, "native batch capacity must be respected");
        batch.clear();
        FlareEffects.begin();
        FlareEffects.add(Double.NaN, 200, 0, 1, 0, 1);
        FlareEffects.add(100, 200, 0, 0, 0, 1);
        FlareEffects.add(100, 200, 0, 1, 0, 20);
        FlareEffects.add(100, 200, Double.POSITIVE_INFINITY, 1, 0, 1);
        FlareEffects.end();
        FlareEffects.capture(frame);
        check(count(frame) == 0, "invalid or expired signals must not render");
        FlareEffects.begin();
        for (int i = 0; i < 50; i++) FlareEffects.add(100, 200, 0, 1, 0, 5);
        FlareEffects.end();
        FlareEffects.capture(frame);
        check(count(frame) == 8 * 13, "signal count must be bounded");
        batch.clear();
        FlareEffects.clear();
        FlareEffects.capture(frame);
        check(count(frame) == 0, "reset must clear signals");
        System.out.println("PASS: actual Viewpoint FlameDraws integration, emissive flag, UVs, floor conversion, capacity, texture retry, bounds and cleanup");
    }
}
