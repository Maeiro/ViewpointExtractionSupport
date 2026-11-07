package maeiro.viewpointextractionsupport;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Set;

public final class HideoutWalls {
    private static final Set<String> FULL_WALLS = Set.of(
            "industry_trucks_01_4", "industry_trucks_01_5", "industry_trucks_01_6",
            "industry_trucks_01_48", "industry_trucks_01_49", "industry_trucks_01_50",
            "location_sewer_01_8", "location_sewer_01_9", "location_sewer_01_10",
            "walls_garage_01_32", "walls_garage_01_33", "walls_garage_01_34");
    private static final Set<String> LOW_PANELS = Set.of(
            "industry_bunker_01_24", "industry_bunker_01_25", "industry_bunker_01_26",
            "industry_railroad_05_40", "industry_railroad_05_41", "industry_railroad_05_42");
    private static FaceFields fields;
    private static boolean failed;
    private static boolean reported;

    private HideoutWalls() {
    }

    public static void keepFullHeight(Object face) {
        if (face == null || failed) return;

        try {
            if (fields == null) fields = new FaceFields(face.getClass());
            fields.keepFullHeight(face);
        } catch (ReflectiveOperationException | RuntimeException error) {
            failed = true;
            System.err.println("[Viewpoint Extraction Support] Hideout wall rendering unavailable: " + error);
        }
    }

    private static final class FaceFields {
        private final Field wall, tile, rule;
        private final Method getName;
        private final Object roomTile, roomSheet, roomPaint;

        private FaceFields(Class<?> face) throws ReflectiveOperationException {
            wall = face.getField("wall");
            tile = face.getField("tile");
            rule = face.getField("rule");
            getName = wall.getType().getMethod("getName");
            roomTile = rule.getType().getField("ROOM_TILE").get(null);
            roomSheet = rule.getType().getField("ROOM_SHEET").get(null);
            roomPaint = rule.getType().getField("ROOM_PAINT").get(null);
        }

        private void keepFullHeight(Object face) throws ReflectiveOperationException {
            Object selection = rule.get(face);
            if (selection != roomTile && selection != roomSheet) return;

            Object original = wall.get(face);
            Object borrowed = tile.get(face);
            if (original == null || borrowed == null || original == borrowed) return;

            String originalName = (String) getName.invoke(original);
            if (originalName == null || !FULL_WALLS.contains(originalName)) return;

            String borrowedName = (String) getName.invoke(borrowed);
            if (borrowedName == null || !LOW_PANELS.contains(borrowedName)) return;

            // Use Viewpoint's solid room-color fallback when the borrowed panel is shorter than the wall.
            rule.set(face, roomPaint);
            tile.set(face, null);
            if (!reported) {
                reported = true;
                System.out.println("[Viewpoint Extraction Support] Keeping full height on layered hideout walls.");
            }
        }
    }
}
