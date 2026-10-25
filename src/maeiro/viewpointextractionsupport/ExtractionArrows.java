package maeiro.viewpointextractionsupport;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

public final class ExtractionArrows {
    private static final Map<Object, Boolean> arrows = Collections.synchronizedMap(new WeakHashMap<>());
    private static final ThreadLocal<ArrayList<Object>> hidden = ThreadLocal.withInitial(ArrayList::new);
    private static Method active, removed, setActive, x, y, z;
    private static Field viewEnabled;
    private static boolean failed;

    private ExtractionArrows() {
    }

    public static void track(String texture, Object arrow) {
        if (arrow != null && "Item_Rope2".equals(texture)) arrows.put(arrow, Boolean.TRUE);
    }

    public static void beforeRender() {
        if (failed || arrows.isEmpty()) return;
        try {
            synchronized (arrows) {
                var iterator = arrows.keySet().iterator();
                while (iterator.hasNext()) {
                    Object arrow = iterator.next();
                    if (active == null) initialize(arrow);
                    if (Boolean.TRUE.equals(removed.invoke(arrow))) {
                        iterator.remove();
                        continue;
                    }
                    if (!viewEnabled.getBoolean(null) || !Boolean.TRUE.equals(active.invoke(arrow))) continue;
                    if (GroundAreas.replacesArrow(((Number) x.invoke(arrow)).intValue(),
                            ((Number) y.invoke(arrow)).intValue(), ((Number) z.invoke(arrow)).intValue())) {
                        hidden.get().add(arrow);
                        setActive.invoke(arrow, false);
                    }
                }
            }
        } catch (ReflectiveOperationException error) {
            afterRender();
            fail(error);
        }
    }

    public static void afterRender() {
        try {
            for (Object arrow : hidden.get()) {
                if (!Boolean.TRUE.equals(removed.invoke(arrow))) setActive.invoke(arrow, true);
            }
        } catch (ReflectiveOperationException error) {
            fail(error);
        } finally {
            hidden.get().clear();
        }
    }

    private static void initialize(Object arrow) throws ReflectiveOperationException {
        Class<?> type = arrow.getClass();
        removed = type.getMethod("isRemoved");
        setActive = type.getMethod("setActive", boolean.class);
        x = type.getMethod("getX");
        y = type.getMethod("getY");
        z = type.getMethod("getZ");
        viewEnabled = Class.forName("viewpoint.core.View").getField("enabled");
        active = type.getMethod("isActive");
    }

    private static void fail(ReflectiveOperationException error) {
        if (!failed) System.err.println("[Viewpoint Extraction Support] Extraction arrow filtering unavailable: " + error);
        failed = true;
    }
}
