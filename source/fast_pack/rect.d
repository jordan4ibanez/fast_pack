/** 
 * The texture packer collision detection & OpenGL worker structs.
 */

module fast_pack.rect;

/**
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

    /// Inverse AABB point check, best case: 1 cpu cycle, worst case: 4 cpu cycles
    bool containsPoint(uint x, uint y) {
        return !(x < this.x || x > this.x + this.width - 1 || y < this.y || y > this.y + this.height - 1);
    }

    /// Check if a point is on the texture's edge
    bool isEdge(uint x, uint y) {
        return x == this.x || x == this.x + this.width - 1 || y == this.y || y == this.y + this.height - 1;
    }

    /// Inverse AABB check, best cast: 1 cpu cycle, worst cast: 4 cpu cycles
    bool collides(Rect AABB, uint padding) {
        return !(AABB.x + AABB.width + padding - 1 < this.x ||
                 AABB.x > this.x + this.width + padding ||
                 AABB.y + AABB.height + padding - 1 < this.y ||
                 AABB.y > this.y + this.height + padding);
    }
}

/**
 * A double based struct to directly map textures to vertices in OpenGL
 * 
 * This has different variables because it is easier to understand when mapping textures
 */

struct GLRectDouble {
    /// Top left
    double minX = 0.0;
    double minY = 0.0;
    /// Bottom right
    double maxX = 0.0;
    double maxY = 0.0;
}

/**
 * A float based struct to directly map textures to vertices in OpenGL
 *
 * This has different variables because it is easier to understand when mapping textures
 */
struct GLRectFloat {
    /// Top left
    float minX = 0.0;
    float minY = 0.0;
    /// Bottom right
    float maxX = 0.0;
    float maxY = 0.0;
}