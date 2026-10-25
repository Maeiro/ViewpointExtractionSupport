package visiblehelicopter;

public final class HelicopterAudio {
    public static boolean deaf;

    private static float ground(float x, float y) { return 7.0f; }

    private static double distance(float x, float y, float height) {
        return deaf ? Double.POSITIVE_INFINITY : Math.hypot(Math.hypot(x - 100, y - 200), height - 7);
    }
}
