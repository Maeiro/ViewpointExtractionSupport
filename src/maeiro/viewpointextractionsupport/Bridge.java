package maeiro.viewpointextractionsupport;

import java.lang.reflect.Method;
import me.zed_0xff.zombie_buddy.Exposer;

public final class Bridge {
    private static Method triggerEvent;
    private static volatile boolean suppressNative;
    private static boolean warned;

    static {
        Exposer.exposeClass(Bridge.class, "ViewpointExtractionSupportBridge");
    }

    private Bridge() {
    }

    public static void suppressNative(boolean suppress) {
        suppressNative = suppress;
    }

    public static boolean allowNative(boolean original) {
        return original && !suppressNative;
    }

    public static void nativeAudioPosition(double x, double y, double height) {
        ExtractionAudio.position(x, y, height);
    }

    public static void clearNativeAudioPosition() {
        ExtractionAudio.clear();
    }

    public static void beginAreas() {
        GroundAreas.begin();
    }

    public static void area(double x, double y, double z, double radius) {
        GroundAreas.add(x, y, z, radius);
    }

    public static void endAreas() {
        GroundAreas.end();
    }

    public static void clearAreas() {
        GroundAreas.clear();
    }

    public static void beginRopes() {
        ExtractionRope.begin();
    }

    public static void rope(String id, double x, double y, double groundX, double groundY, double groundHeight,
            double flightHeight, double progress, double alpha) {
        ExtractionRope.add(id, x, y, groundX, groundY, groundHeight, flightHeight, progress, alpha);
    }

    public static void endRopes() {
        ExtractionRope.end();
    }

    public static void clearRopes() {
        ExtractionRope.clear();
    }

    public static void collectFlights() {
        try {
            if (triggerEvent == null) {
                triggerEvent = Class.forName("zombie.Lua.LuaEventManager").getMethod("triggerEvent", String.class);
            }
            triggerEvent.invoke(null, "OnViewpointExtractionFlights");
        } catch (ReflectiveOperationException error) {
            suppressNative = false;
            if (!warned) {
                warned = true;
                System.err.println("[Viewpoint Extraction Support] Flight collection unavailable: " + error);
            }
        }
    }
}
