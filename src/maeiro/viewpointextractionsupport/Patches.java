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

    @Patch(className = "viewpoint.world.Blood", methodName = "snapshot", warmUp = true)
    public static class ExtractionGroundAreas {
        @Patch.OnExit
        public static void exit(@Patch.Argument(0) Object frame, @Patch.Argument(1) Object cell) {
            GroundAreas.capture(frame, cell);
        }
    }

    @Patch(className = "zombie.iso.WorldMarkers", methodName = "addDirectionArrow", warmUp = true)
    public static class TrackExtractionArrow {
        @Patch.OnExit
        public static void exit(@Patch.Argument(4) String texture, @Patch.Return(readOnly = true) Object arrow) {
            ExtractionArrows.track(texture, arrow);
        }
    }

    @Patch(className = "zombie.iso.WorldMarkers", methodName = "renderDirectionArrow", warmUp = true)
    public static class ExtractionArrowVisibility {
        @Patch.OnEnter
        public static void enter() {
            ExtractionArrows.beforeRender();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit() {
            ExtractionArrows.afterRender();
        }
    }
}
