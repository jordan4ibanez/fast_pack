module resources.rect;

/*
 * AABB bounding box for textures
 */
struct Rect {
    uint x = 0;
    uint y = 0;
    uint width = 0;
    uint height = 0;

    // Inverse AABB point check, best case: 1 cpu cycle, worst case: 4 cpu cycles
    bool containsPoint(uint x, uint y) {
        return !(x < this.x || x > this.x + this.width || y < this.y || y > this.y + this.width);
    }

    // Check if a point is on the texture's edge
    bool isEdge(uint x, uint y) {
        return x == this.x || x == this.x + this.width - 1 || y == this.y || y == this.y + this.height - 1;
    }
}