package maeiro.viewpointextractionsupport;

import me.zed_0xff.zombie_buddy.Patch;

public final class Patches {
    private Patches() {
    }

    @Patch(className = "visiblehelicopter.LuaBridge", methodName = "endFlights", warmUp = true)
    public static class CollectExtractionFlights {
        @Patch.OnEnter
        public static void enter() {
            Bridge.collectFlights();
        }
    }

    @Patch(className = "visiblehelicopter.NativeFlight", methodName = "sample", warmUp = true)
    public static class NativeExtractionVisual {
        @Patch.OnExit
        public static void exit(@Patch.Return(readOnly = false) boolean result) {
            result = Bridge.allowNative(result);
        }
    }

    @Patch(className = "visiblehelicopter.HelicopterAudio", methodName = "update", warmUp = true)
    public static class NativeExtractionAudio {
        @Patch.OnExit
        public static void exit(@Patch.Argument(1) long event, @Patch.Argument(2) float volume) {
            ExtractionAudio.update(event, volume);
        }
    }
}
