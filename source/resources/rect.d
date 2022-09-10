module resources.rect;

/*
 * AABB bounding box for textures
 */
struct Rect {
    uint x = 0;
    uint y = 0;
    uint width = 0;
    uint height = 0;

    this(uint x, uint y, uint width, uint height) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }

    // Inverse AABB point check, best case: 1 cpu cycle, worst case: 4 cpu cycles
    bool containsPoint(uint x, uint y) {
        return !(x < this.x || x > this.x + this.width - 1 || y < this.y || y > this.y + this.height - 1);
    }

    // Check if a point is on the texture's edge
    bool isEdge(uint x, uint y) {
        return x == this.x || x == this.x + this.width - 1 || y == this.y || y == this.y + this.height - 1;
    }

    // Inverse AABB check, best cast: 1 cpu cycle, worst cast: 4 cpu cycles
    bool collides(Rect AABB) {
        return !(AABB.x + AABB.width - 1 < this.x ||
                 AABB.x > this.x + this.width ||
                 AABB.y + AABB.height - 1 < this.y ||
                 AABB.y > this.y + this.height );
    }
}