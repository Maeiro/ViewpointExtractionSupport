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

    public static Object compassCreate(Object collection, String icon, double x, double y,
            double r, double g, double b, double a) throws ReflectiveOperationException {
        Object symbol = collection.getClass().getMethod("addTexture", String.class, float.class, float.class,
                float.class, float.class, float.class, float.class)
                .invoke(collection, icon, (float) x, (float) y, (float) r, (float) g, (float) b, (float) a);
        symbol.getClass().getMethod("setPrivate").invoke(symbol);
        symbol.getClass().getMethod("setUserDefined", boolean.class).invoke(symbol, true);
        symbol.getClass().getMethod("setAnchor", float.class, float.class).invoke(symbol, 0.5f, 0.5f);
        symbol.getClass().getMethod("setScale", float.class).invoke(symbol, 0.65f);
        return symbol;
    }

    public static int compassIndex(Object collection, Object symbol) throws ReflectiveOperationException {
        return (Integer) collection.getClass().getMethod("indexOf",
                Class.forName("zombie.worldMap.symbols.WorldMapBaseSymbol")).invoke(collection, symbol);
    }

    public static void compassRemove(Object collection, Object symbol) throws ReflectiveOperationException {
        collection.getClass().getMethod("removeSymbol",
                Class.forName("zombie.worldMap.symbols.WorldMapBaseSymbol")).invoke(collection, symbol);
    }

    public static void compassSave() throws ReflectiveOperationException {
        Class.forName("zombie.inventory.types.MapItem").getMethod("SaveWorldMap").invoke(null);
    }

    public static void registerFtzAircraft() {
        FtzAircraftCatalog.install();
    }

    public static void configureFtzAircraft(boolean hummingbird, boolean orca, boolean hellcat) {
        FtzAircraftCatalog.configure(hummingbird, orca, hellcat);
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
            double flightHeight, double progress, double alpha, String aircraftId) {
        ExtractionRope.add(id, x, y, groundX, groundY, groundHeight, flightHeight, progress, alpha, aircraftId);
    }

    public static void endRopes() {
        ExtractionRope.end();
    }

    public static void clearRopes() {
        ExtractionRope.clear();
    }

    public static void beginFlares() {
        FlareEffects.begin();
    }

    public static void flare(double x, double y, double z, double dx, double dy, double age) {
        FlareEffects.add(x, y, z, dx, dy, age);
    }

    public static void endFlares() {
        FlareEffects.end();
    }

    public static void clearFlares() {
        FlareEffects.clear();
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
