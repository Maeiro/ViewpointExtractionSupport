package zombie.core.textures;

public final class Texture {
    public static boolean loaded = true;

    public static Texture getSharedTexture(String path) {
        if (!path.equals("media/textures/ViewpointExtractionSupport_FlareGlow.png")
                && !path.equals("media/textures/ViewpointExtractionSupport_FlareSmoke.png")) {
            throw new AssertionError(path);
        }
        return new Texture();
    }

    public boolean isReady() { return loaded; }
    public float getXStart() { return 0.1f; }
    public float getYStart() { return 0.2f; }
    public float getXEnd() { return 0.9f; }
    public float getYEnd() { return 0.8f; }
}
