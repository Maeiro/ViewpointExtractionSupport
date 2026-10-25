import maeiro.viewpointextractionsupport.ExtractionAudio;
import visiblehelicopter.AudioDistance;
import visiblehelicopter.HelicopterAudio;
import visiblehelicopter.LuaBridge;
import fmod.javafmod;

public final class ExtractionAudioTest {
    private static void near(float actual, float expected) {
        if (Math.abs(actual - expected) > 0.0001f) throw new AssertionError(actual + " != " + expected);
    }

    private static void unchanged(Runnable action) {
        int before = javafmod.positionCalls + javafmod.volumeCalls;
        action.run();
        if (javafmod.positionCalls + javafmod.volumeCalls != before) throw new AssertionError("Unexpected FMOD update");
    }

    public static void main(String[] args) {
        unchanged(() -> ExtractionAudio.update(42, 0.75f));
        ExtractionAudio.position(100, 200, 12);
        ExtractionAudio.update(42, 0.75f);
        if (javafmod.event != 42) throw new AssertionError("Must reuse the existing event");
        near(javafmod.x, 100);
        near(javafmod.y, 200);
        near(javafmod.z, 19 * 3 / 2.4494896f);
        near(javafmod.volume, AudioDistance.volume(0.75f, 12));
        if (javafmod.volume <= 0) throw new AssertionError("Nearby extraction must remain audible");

        ExtractionAudio.position(1517, 200, 120);
        ExtractionAudio.update(42, 0.75f);
        near(javafmod.x, 1517);
        near(javafmod.volume, 0);

        ExtractionAudio.position(100, 200, 12);
        HelicopterAudio.deaf = true;
        ExtractionAudio.update(42, 0.75f);
        near(javafmod.volume, 0);
        HelicopterAudio.deaf = false;
        ExtractionAudio.update(42, 0);
        near(javafmod.volume, 0);

        LuaBridge.viewActive = false;
        unchanged(() -> ExtractionAudio.update(42, 0.75f));
        LuaBridge.viewActive = true;
        LuaBridge.audioEnabled = false;
        unchanged(() -> ExtractionAudio.update(42, 0.75f));
        LuaBridge.audioEnabled = true;
        unchanged(() -> ExtractionAudio.update(0, 0.75f));
        ExtractionAudio.position(Double.NaN, 200, 12);
        unchanged(() -> ExtractionAudio.update(42, 0.75f));
        ExtractionAudio.position(100, 200, 12);
        ExtractionAudio.clear();
        unchanged(() -> ExtractionAudio.update(42, 0.75f));
        System.out.println("ExtractionAudioTest: existing event, model position, terrain/altitude, real VHE attenuation, deafness, isometric and cleanup checks passed");
    }
}
