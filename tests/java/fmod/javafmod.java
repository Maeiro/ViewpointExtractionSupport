package fmod;

public final class javafmod {
    public static long event;
    public static float x, y, z, volume;
    public static int positionCalls, volumeCalls;

    public static int FMOD_Studio_EventInstance3D(long id, float worldX, float worldY, float worldZ) {
        event = id;
        x = worldX;
        y = worldY;
        z = worldZ;
        positionCalls++;
        return 0;
    }

    public static int FMOD_Studio_EventInstance_SetVolume(long id, float value) {
        event = id;
        volume = value;
        volumeCalls++;
        return 0;
    }
}
