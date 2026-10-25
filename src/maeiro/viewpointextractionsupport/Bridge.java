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
