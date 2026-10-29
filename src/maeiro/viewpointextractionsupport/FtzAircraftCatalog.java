package maeiro.viewpointextractionsupport;

import java.lang.reflect.Constructor;
import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Arrays;

final class FtzAircraftCatalog {
    private static final String CATALOG = "visiblehelicopter.AircraftCatalog";
    private static final String ASSETS = "visiblehelicopter.AircraftAssets";
    private static final String WORKSHOP_ID = "3825500218";
    private static volatile boolean installed;
    private static volatile boolean attempted;
    private static volatile boolean configurationFailed;
    private static int appliedMask;

    private FtzAircraftCatalog() {
    }

    static synchronized void install() {
        if (installed || attempted) return;
        attempted = true;
        try {
            Class<?> catalog = Class.forName(CATALOG);
            Class<?> aircraftType = Class.forName(CATALOG + "$Aircraft");
            Class<?> partType = Class.forName(CATALOG + "$Part");
            Constructor<?> aircraftConstructor = aircraftType.getDeclaredConstructor(String.class,
                    String.class, String.class, String.class, float.class, float.class,
                    Array.newInstance(partType, 0).getClass());
            Constructor<?> partConstructor = partType.getDeclaredConstructor(String.class, String.class,
                    float.class, float.class, float.class, int.class, float.class, float.class, float.class);
            aircraftConstructor.setAccessible(true);
            partConstructor.setAccessible(true);

            Object[] existing = (Object[]) catalog.getField("ALL").get(null);
            Object[] extended = Arrays.copyOf(existing, existing.length + 3);
            extended[existing.length] = aircraftConstructor.newInstance("FTZ_Hummingbird", "FTZ Hummingbird",
                    WORKSHOP_ID, "42", 1f, 0f, parts(partConstructor, "NyxHummingbird", "Olive",
                            1.3521f, 0.0002f, 0.8996f, 0.3108f, -3.745f));
            extended[existing.length + 1] = aircraftConstructor.newInstance("FTZ_Orca", "FTZ Orca",
                    WORKSHOP_ID, "42", 1f, 0f, parts(partConstructor, "NyxOrca", "Hex",
                            2.137f, 0.0012f, 0.5812f, 0.1872f, -6.2778f));
            extended[existing.length + 2] = aircraftConstructor.newInstance("FTZ_Hellcat", "FTZ Hellcat",
                    WORKSHOP_ID, "42", 1f, 0f, parts(partConstructor, "NyxHellcat", "Green",
                            1.5948f, -0.0001f, 1.5297f, 0.3761f, -5.9647f));
            Field allAircraft = catalog.getField("ALL");

            Class<?> assets = Class.forName(ASSETS);
            Field allAssets = assets.getDeclaredField("ALL");
            allAssets.setAccessible(true);
            Object[] oldAssets = (Object[]) allAssets.get(null);
            Constructor<?> assetConstructor = assets.getDeclaredConstructor(aircraftType);
            assetConstructor.setAccessible(true);
            Object[] extendedAssets = Arrays.copyOf(oldAssets, extended.length);
            for (int i = oldAssets.length; i < extended.length; i++) {
                extendedAssets[i] = assetConstructor.newInstance(extended[i]);
            }
            Field cachedMask = assets.getDeclaredField("cachedMask");
            cachedMask.setAccessible(true);

            putStatic(allAssets, extendedAssets);
            putStatic(allAircraft, extended);
            cachedMask.setInt(null, -1);
            installed = true;
        } catch (ReflectiveOperationException | RuntimeException error) {
            System.err.println("[Viewpoint Extraction Support] FTZ aircraft registration unavailable: " + error);
        }
    }

    static synchronized void configure(boolean hummingbird, boolean orca, boolean hellcat) {
        if (!installed || configurationFailed) return;
        try {
            Class<?> catalog = Class.forName(CATALOG);
            Class<?> assets = Class.forName(ASSETS);
            Field enabledMask = assets.getDeclaredField("enabledMask");
            Field cachedMask = assets.getDeclaredField("cachedMask");
            enabledMask.setAccessible(true);
            cachedMask.setAccessible(true);
            int mask = 0;
            if (hummingbird) mask |= modelBit(catalog, "FTZ_Hummingbird");
            if (orca) mask |= modelBit(catalog, "FTZ_Orca");
            if (hellcat) mask |= modelBit(catalog, "FTZ_Hellcat");
            enabledMask.setInt(null, (enabledMask.getInt(null) & ~appliedMask) | mask);
            appliedMask = mask;
            cachedMask.setInt(null, -1);
        } catch (ReflectiveOperationException | RuntimeException error) {
            configurationFailed = true;
            System.err.println("[Viewpoint Extraction Support] FTZ aircraft selection unavailable: " + error);
        }
    }

    private static int modelBit(Class<?> catalog, String id) throws ReflectiveOperationException {
        int index = ((Number) catalog.getMethod("index", String.class).invoke(null, id)).intValue();
        return index < 0 || index >= Integer.SIZE - 1 ? 0 : 1 << index;
    }

    private static Object parts(Constructor<?> constructor, String model, String livery,
            float mainY, float mainX, float tailY, float tailX, float tailZ) throws ReflectiveOperationException {
        Class<?> partType = constructor.getDeclaringClass();
        Object result = Array.newInstance(partType, 3);
        Array.set(result, 0, constructor.newInstance(model + "Body", "Vehicles/Vehicles_" + model + "_" + livery,
                0f, 0f, 0f, 0, 0f, 0f, 0f));
        Array.set(result, 1, constructor.newInstance(model + "MainRunModel", "Vehicles/Vehicles_" + model + "_" + livery,
                mainX, mainY, 0f, 1, 5f, 0f, 0f));
        Array.set(result, 2, constructor.newInstance(model + "TailModel", "Vehicles/Vehicles_" + model + "_" + livery,
                tailX, tailY, tailZ, 2, 5f, 0f, 0f));
        return result;
    }

    private static void putStatic(Field field, Object value) throws ReflectiveOperationException {
        Class<?> unsafeType = Class.forName("sun.misc.Unsafe");
        Field unsafeField = unsafeType.getDeclaredField("theUnsafe");
        unsafeField.setAccessible(true);
        Object unsafe = unsafeField.get(null);
        Method base = unsafeType.getMethod("staticFieldBase", Field.class);
        Method offset = unsafeType.getMethod("staticFieldOffset", Field.class);
        Method putObject = unsafeType.getMethod("putObject", Object.class, long.class, Object.class);
        putObject.invoke(unsafe, base.invoke(unsafe, field), offset.invoke(unsafe, field), value);
    }
}
