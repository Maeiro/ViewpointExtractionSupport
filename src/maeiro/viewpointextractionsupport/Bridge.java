package maeiro.viewpointextractionsupport;

import java.lang.reflect.Method;
import me.zed_0xff.zombie_buddy.Exposer;

public final class Bridge {
    private static final String NIGHT_LUCK_MOODLE = "viewpointextractionsupport:night_luck";
    private static Method triggerEvent;
    private static Method moodleTypeAccessor;
    private static Method moodleTranslationNameAccessor;
    private static volatile boolean suppressNative;
    private static volatile float nightLootMultiplier = 1.0f;
    private static volatile boolean nightLuckMoodleActive;
    private static volatile boolean nightMoodleRefreshNeeded;
    private static boolean warned;

    static {
        Exposer.exposeClass(Bridge.class, "ViewpointExtractionSupportBridge");
    }

    private Bridge() {
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

    public static void setNightFeatureState(boolean enabled, int lootBonusPercent, boolean isNight) {
        int bonus = Math.max(0, Math.min(500, lootBonusPercent));
        nightLootMultiplier = enabled && isNight ? 1.0f + bonus / 100.0f : 1.0f;

        boolean moodleActive = enabled && isNight && bonus > 0;
        if (nightLuckMoodleActive != moodleActive) {
            nightLuckMoodleActive = moodleActive;
            nightMoodleRefreshNeeded = true;
        }
    }

    public static float scaleNightLootChance(float chance, Object container) {
        if (container == null) {
            return chance;
        }
        return chance * nightLootMultiplier;
    }

    public static int nightLuckMoodleLevel(Object moodle, int level) {
        return nightLuckMoodleActive && isNightLuckMoodle(moodle) ? 1 : level;
    }

    public static int nightLuckMoodleGoodBadNeutral(Object moodleType, int value) {
        return nightLuckMoodleActive && isNightLuckMoodleType(moodleType) ? 1 : value;
    }

    public static boolean nightMoodleRefresh(boolean refreshNeeded) {
        if (refreshNeeded || !nightMoodleRefreshNeeded) {
            nightMoodleRefreshNeeded = false;
            return refreshNeeded;
        }
        nightMoodleRefreshNeeded = false;
        return true;
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

    private static boolean isNightLuckMoodle(Object moodle) {
        if (moodle == null) {
            return false;
        }
        try {
            if (moodleTypeAccessor == null) {
                moodleTypeAccessor = moodle.getClass().getMethod("getMoodleType");
            }
            return isNightLuckMoodleType(moodleTypeAccessor.invoke(moodle));
        } catch (ReflectiveOperationException error) {
            return false;
        }
    }

    private static boolean isNightLuckMoodleType(Object moodleType) {
        if (moodleType == null) {
            return false;
        }
        try {
            if (moodleTranslationNameAccessor == null) {
                moodleTranslationNameAccessor = moodleType.getClass().getMethod("getTranslationName");
            }
            return NIGHT_LUCK_MOODLE.equals(moodleTranslationNameAccessor.invoke(moodleType));
        } catch (ReflectiveOperationException error) {
            return false;
        }
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
