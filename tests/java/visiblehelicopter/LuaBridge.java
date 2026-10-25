package visiblehelicopter;

public final class LuaBridge {
    public static boolean viewActive = true;
    public static boolean audioEnabled = true;

    public static boolean active() { return viewActive; }
    public static boolean directional() { return audioEnabled; }
}
