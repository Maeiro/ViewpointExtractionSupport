package zombie.iso;

public final class IsoGridSquare {
    public boolean floor = true;

    public Object getFloor() { return floor ? this : null; }
}
