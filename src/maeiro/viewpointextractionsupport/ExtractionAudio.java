package maeiro.viewpointextractionsupport;

import java.lang.reflect.Method;

public final class ExtractionAudio {
    private static final float STOREY_METRES = 2.4494896f;
    private static volatile Position position;
    private static Method active, directional, ground, distance, volume, setPosition, setVolume;
    private static boolean failed;

    private record Position(float x, float y, float height) {
    }

    private ExtractionAudio() {
    }

    public static void position(double x, double y, double height) {
        if (Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(height)) {
            position = new Position((float) x, (float) y, (float) height);
        } else {
            clear();
        }
    }

    public static void clear() {
        position = null;
    }

    public static void update(long event, float originalVolume) {
        Position source = position;
        if (source == null || event == 0L || failed || !Float.isFinite(originalVolume)) return;
        try {
            if (active == null) initialize();
            if (!Boolean.TRUE.equals(active.invoke(null)) || !Boolean.TRUE.equals(directional.invoke(null))) return;
            float height = source.height + ((Number) ground.invoke(null, source.x, source.y)).floatValue();
            double metres = ((Number) distance.invoke(null, source.x, source.y, height)).doubleValue();
            float gain = ((Number) volume.invoke(null, originalVolume, metres)).floatValue();
            setPosition.invoke(null, event, source.x, source.y, height * 3.0f / STOREY_METRES);
            setVolume.invoke(null, event, gain);
        } catch (ReflectiveOperationException error) {
            failed = true;
            System.err.println("[Viewpoint Extraction Support] Extraction audio positioning unavailable: " + error);
        }
    }

    private static void initialize() throws ReflectiveOperationException {
        Class<?> bridge = Class.forName("visiblehelicopter.LuaBridge");
        Class<?> audio = Class.forName("visiblehelicopter.HelicopterAudio");
        ground = audio.getDeclaredMethod("ground", float.class, float.class);
        ground.setAccessible(true);
        distance = audio.getDeclaredMethod("distance", float.class, float.class, float.class);
        distance.setAccessible(true);
        volume = Class.forName("visiblehelicopter.AudioDistance").getMethod("volume", float.class, double.class);
        Class<?> fmod = Class.forName("fmod.javafmod");
        setPosition = fmod.getMethod("FMOD_Studio_EventInstance3D", long.class, float.class, float.class, float.class);
        setVolume = fmod.getMethod("FMOD_Studio_EventInstance_SetVolume", long.class, float.class);
        directional = bridge.getMethod("directional");
        active = bridge.getMethod("active");
    }
}
