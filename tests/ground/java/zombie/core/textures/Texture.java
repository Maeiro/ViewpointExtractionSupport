package zombie.core.textures;

public final class Texture {
    public static boolean loaded = true;
    private final int id;

    private Texture(int id) { this.id = id; }
    public static Texture getSharedTexture(String path) {
        if (!path.equals("media/textures/ViewpointExtractionSupport_Marker.png")) throw new AssertionError(path);
        return new Texture(33);
    }
    public boolean isReady() { return loaded; }
    public int getID() { return id; }
    public float getXStart() { return 0.1f; }
    public float getYStart() { return 0.2f; }
    public float getXEnd() { return 0.9f; }
    public float getYEnd() { return 0.8f; }
}
