import java.lang.reflect.Field;
import maeiro.viewpointextractionsupport.GroundAreas;
import maeiro.viewpointextractionsupport.ExtractionArrows;
import viewpoint.core.View;
import viewpoint.render.BloodDraws;
import zombie.core.textures.Texture;
import zombie.iso.IsoGridSquare;

public final class GroundAreasTest {
    public static final class Scene {
        public final BloodDraws blood = new BloodDraws();
    }

    public static final class Frame {
        public float camX = 100, camY = 200, camZ = 2;
        public final Scene scene = new Scene();
    }

    public static final class Cell {
        public final IsoGridSquare square = new IsoGridSquare();
        public boolean loaded = true;
        public int lastZ;

        public IsoGridSquare getGridSquare(int x, int y, int z) {
            if (x != 100 || y != 200) throw new AssertionError("Wrong world square");
            lastZ = z;
            return loaded ? square : null;
        }
    }

    public static final class Arrow {
        public boolean active = true;
        public int x = 100, y = 200, z = 2;

        public boolean isActive() { return active; }
        public boolean isRemoved() { return false; }
        public void setActive(boolean value) { active = value; }
        public int getX() { return x; }
        public int getY() { return y; }
        public int getZ() { return z; }
    }

    private static Object field(BloodDraws batch, String name) throws Exception {
        Field field = BloodDraws.class.getDeclaredField(name);
        field.setAccessible(true);
        return field.get(batch);
    }

    private static void count(BloodDraws batch, int expected) throws Exception {
        if ((int) field(batch, "count") != expected) throw new AssertionError("Unexpected decal count");
    }

    private static void near(float actual, float expected) {
        if (Math.abs(actual - expected) > 0.00001f) throw new AssertionError(actual + " != " + expected);
    }

    private static void area(double x, double z, double radius) {
        GroundAreas.begin();
        GroundAreas.add(x, 200.5, z, radius);
        GroundAreas.end();
    }

    public static void main(String[] args) throws Exception {
        Frame frame = new Frame();
        Cell cell = new Cell();
        BloodDraws batch = frame.scene.blood;
        area(100.5, 2, 3);
        GroundAreas.capture(frame, cell);
        count(batch, 64);
        float[] values = (float[]) field(batch, "values");
        int[] textures = (int[]) field(batch, "textures");
        if (textures[0] != 33 || textures[1] != 33) throw new AssertionError("Gradient texture missing");
        near(values[0], -3.5f);
        near(values[1], 0.015f);
        near(values[2], -0.5f);
        near(values[9], 2.2f);
        near(values[19], 1);
        near(values[24 + 19], -1);
        near(values[7], 1);
        near(values[11], 0.82f);
        near(values[18], 0.12f);
        near(values[24 + 3], 0.65f);
        near(values[12], 0.1f);
        near(values[13], 0.8f);
        near(values[14], 0.8f);
        near(values[17], -0.6f);
        for (int segment = 0; segment < 32; segment++) {
            int at = segment * 48;
            float worldX = frame.camX - values[at], worldY = frame.camY - values[at + 2];
            near((float) Math.hypot(worldX - 100.5f, worldY - 200.5f), 3);
            int next = ((segment + 1) % 32) * 48;
            near(values[at] + values[at + 4], values[next]);
            near(values[at + 2] + values[at + 6], values[next + 2]);
            near(values[at + 9], 2.2f);
            near(values[at + 19], 1);
            near(values[at + 24 + 19], -1);
        }
        if (!GroundAreas.replacesArrow(100, 200, 2) || GroundAreas.replacesArrow(100, 200, 3)) throw new AssertionError("Wrong arrow association");

        Arrow extraction = new Arrow(), unrelated = new Arrow(), otherPoint = new Arrow(), inactive = new Arrow();
        otherPoint.x++;
        inactive.active = false;
        ExtractionArrows.track("Item_Rope2", extraction);
        ExtractionArrows.track("OtherArrow", unrelated);
        ExtractionArrows.track("Item_Rope2", otherPoint);
        ExtractionArrows.track("Item_Rope2", inactive);
        ExtractionArrows.beforeRender();
        if (extraction.active || !unrelated.active || !otherPoint.active || inactive.active) throw new AssertionError("Only hide the matching extraction arrow");
        ExtractionArrows.afterRender();
        if (!extraction.active || inactive.active) throw new AssertionError("Arrow state must be restored after rendering");
        View.enabled = false;
        ExtractionArrows.beforeRender();
        if (!extraction.active) throw new AssertionError("Keep the isometric arrow");
        ExtractionArrows.afterRender();
        View.enabled = true;

        batch.clear();
        frame.camX += 1;
        GroundAreas.capture(frame, cell);
        near(values[0], -2.5f);
        frame.camX -= 1;

        batch.clear();
        area(100.5, 3, 3);
        GroundAreas.capture(frame, cell);
        if (cell.lastZ != 3) throw new AssertionError("Wrong extraction floor");
        near(values[1], 2.4494896f + 0.015f);

        batch.clear();
        cell.loaded = false;
        GroundAreas.capture(frame, cell);
        count(batch, 0);
        cell.loaded = true;
        cell.square.floor = false;
        GroundAreas.capture(frame, cell);
        count(batch, 0);
        cell.square.floor = true;
        Texture.loaded = false;
        GroundAreas.capture(frame, cell);
        count(batch, 0);
        Texture.loaded = true;
        GroundAreas.capture(frame, cell);
        count(batch, 64);

        batch.clear();
        area(1000, 3, 3);
        GroundAreas.capture(frame, cell);
        count(batch, 0);
        for (double[] invalid : new double[][] { { Double.NaN, 2, 3 }, { 100.5, 2.5, 3 }, { 100.5, 2, -1 } }) {
            area(invalid[0], invalid[1], invalid[2]);
            GroundAreas.capture(frame, cell);
            count(batch, 0);
        }

        float[] empty = new float[6];
        for (int i = 0; i < BloodDraws.MAX; i++) batch.add(1, empty, empty, empty, empty, empty, 1);
        area(100.5, 2, 3);
        GroundAreas.capture(frame, cell);
        count(batch, BloodDraws.MAX);
        if (GroundAreas.replacesArrow(100, 200, 2)) throw new AssertionError("Keep the arrow when the marker cannot render");
        batch.clear();
        GroundAreas.clear();
        GroundAreas.capture(frame, cell);
        count(batch, 0);
        ExtractionArrows.beforeRender();
        if (!extraction.active) throw new AssertionError("Keep the arrow after disabling the marker");
        ExtractionArrows.afterRender();
        System.out.println("GroundAreasTest: real Viewpoint batch, closed cylindrical geometry, inside/outside faces, gradient UVs, camera motion, elevated floors, assets, targeted arrow filtering and cleanup passed");
    }
}
