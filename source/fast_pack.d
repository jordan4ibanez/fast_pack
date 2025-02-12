module fast_pack;

import image;
import std.algorithm.comparison;
import std.algorithm.sorting;
import std.conv;
import std.math.algebraic;
import std.math.rounding;
import std.range;
import std.range.primitives;

private struct PackRect {
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;
    ulong pointingTo = 0;
}

private struct FloatingRectangle {
    double x = 0;
    double y = 0;
    double w = 0;
    double h = 0;
}

struct TexturePoints(T) {
    T topLeft;
    T bottomLeft;
    T bottomRight;
    T topRight;
}

/**
The TexturePacker struct.
You can add more things in after you finalize. But, you will 
need to finalize again. Also, you'll have to re-upload into
the gpu if it's Vulkan or OpenGL.
*/
struct TexturePacker(T) {
private:

    // This is used to get the data to texture map to the atlas.
    FloatingRectangle[T] floatingLookupTable;

    // These two are synchronized.
    immutable(TrueColorImage)[] textures;
    immutable(T)[] keys;

    PackRect[] boxes;
    int canvasWidth = 0;
    int canvasHeight = 0;
    immutable int padding = 0;

public:

    this(int padding) {
        this.padding = padding;
    }

    pragma(inline, true)
    void pack(T key, string textureLocation) {
        this.uploadTexture(key, textureLocation);
    }

    pragma(inline, true)
    void finalize(string outputFileName) {
        this.potpack();
        this.flushToDisk(outputFileName);
    }

    int getCanvasWidth() const {
        return canvasWidth;
    }

    int getCanvasHeight() const {
        return canvasHeight;
    }

    ulong getCount() const {
        return textures.length;
    }

    /// This is getting raw xPos, yPos, width, height.
    /// Type C must implement this (x,y,w,h) as (float or double).
    /// It will be within scale (0.0 - 1.0) of the atlas.
    /// Returns: RectangleType
    pragma(inline, true)
    RectangleType getRectangle(RectangleType)(immutable T key) const {
        // This allows you to automatically downcast and insert into custom types.
        static assert(is(typeof(RectangleType.x) == float) || is(typeof(RectangleType.x) == double),
            "x must be floating point.");
        static assert(is(typeof(RectangleType.y) == float) || is(typeof(RectangleType.y) == double),
            "y must be floating point.");
        static assert(is(typeof(RectangleType.w) == float) || is(typeof(RectangleType.w) == double),
            "w must be floating point.");
        static assert(is(typeof(RectangleType.h) == float) || is(typeof(RectangleType.h) == double),
            "h must be floating point.");

        const(FloatingRectangle)* thisRectangle = key in floatingLookupTable;

        if (!thisRectangle) {
            throw new Error("Key " ~ to!string(key) ~ " does not exist.");
        }

        // x,y,w,h (float or double) is all your type needs.
        RectangleType result;
        result.x = thisRectangle.x;
        result.y = thisRectangle.y;
        result.w = thisRectangle.w;
        result.h = thisRectangle.h;

        return result;
    }

    /// This is getting raw xPos, yPos, width, height.
    /// Type C must implement this (x,y,w,h) as (float or double).
    /// It will be within scale (0.0 - 1.0) of the atlas.
    /// Mutates the variable you give it as a ref.
    pragma(inline, true)
    void getRectangle(RectangleType)(immutable T key, ref RectangleType referenceOutput) {
        referenceOutput = getRectangle!RectangleType(key);
    }

    /// This is getting raw 2D points of a rectangle on the atlas..
    /// Type C must implement this (x,y) as (float or double).
    /// It will be within scale (0.0 - 1.0) of the atlas.
    /// Top to bottom, left to right.
    TexturePoints!Vec2Type getTexturePoints(Vec2Type)(immutable T key) {
        // This allows you to automatically downcast and insert into custom types.
        static assert(is(typeof(Vec2Type.x) == float) || is(typeof(Vec2Type.x) == double), "x must be floating point.");
        static assert(is(typeof(Vec2Type.y) == float) || is(typeof(Vec2Type.y) == double), "y must be floating point.");

        const(FloatingRectangle)* thisRectangle = key in floatingLookupTable;

        if (!thisRectangle) {
            throw new Error("Key " ~ to!string(key) ~ " does not exist.");
        }

        // x,y (float or double) and a this(x,y) constructor is all your type needs.
        TexturePoints!Vec2Type result;

        result.topLeft = Vec2Type(thisRectangle.x, thisRectangle.y);
        result.bottomLeft = Vec2Type(thisRectangle.x, thisRectangle.y + thisRectangle.h);
        result.bottomRight = Vec2Type(thisRectangle.x + thisRectangle.w, thisRectangle.y + thisRectangle
                .h);
        result.topRight = Vec2Type(thisRectangle.x + thisRectangle.w, thisRectangle.y);

        return result;
    }

private:

    pragma(inline, true)
    void flushToDisk(string outputFileName) {
        TrueColorImage atlas = new TrueColorImage(this.canvasWidth, this.canvasHeight);

        foreach (const ref PackRect thisBox; boxes) {

            immutable ulong indexOf = thisBox.pointingTo;

            immutable TrueColorImage thisTexture = this.textures[indexOf];
            immutable(T) thisKey = this.keys[indexOf];

            immutable int xPos = thisBox.x + this.padding;
            immutable int yPos = thisBox.y + this.padding;

            immutable int width = thisBox.w - this.padding;
            immutable int height = thisBox.h - this.padding;

            floatingLookupTable[thisKey] = FloatingRectangle(
                cast(double) xPos / cast(double) this.canvasWidth,
                cast(double) yPos / cast(double) this.canvasHeight,
                cast(double) width / cast(double) this.canvasWidth,
                cast(double) height / cast(double) this.canvasHeight
            );

            foreach (immutable int inImageX; 0 .. width) {
                immutable int inAtlasX = inImageX + xPos;

                foreach (immutable int inImageY; 0 .. height) {
                    immutable int inAtlasY = inImageY + yPos;

                    atlas.setPixel(
                        inAtlasX,
                        inAtlasY,
                        thisTexture.getPixel(
                            inImageX,
                            inImageY
                    ));
                }
            }
        }
        writeImageToPngFile(outputFileName, atlas);
    }

    pragma(inline, true)
    void uploadTexture(T key, string textureLocation) {
        immutable TrueColorImage tempTextureObject = loadImageFromFile(textureLocation).getAsTrueColorImage();

        if (tempTextureObject is null) {
            throw new Error(to!string(key) ~ " is null");
        }

        boxes ~= PackRect(
            0, 0, tempTextureObject.width() + padding, tempTextureObject.height() + padding, textures
                .length
        );

        textures ~= tempTextureObject;
        keys ~= key;
    }

    /// This is the very nice packing algorithm. :)
    pragma(inline, true)
    void potpack() {

        //? You can thank them: https://github.com/mapbox/potpack
        //? I just translated and tweaked this.

        // Calculate total box area and maximum box width.
        int area = 0;
        int maxWidth = 0;

        foreach (immutable box; boxes) {
            area += box.w * box.h;
            maxWidth = max(maxWidth, box.w);
        }

        // Sort the boxes for insertion by height, descending.
        boxes = boxes.sort!((a, b) {
            if (a.h == b.h) {
                return a.w > b.w;
            }
            return a.h > b.h;
            // This is by area.
            // return a.w * a.h > b.w * b.h;
        }).release();

        // Aim for a squarish resulting container,
        // slightly adjusted for sub-100% space utilization.
        immutable int startWidth = cast(int) max(ceil(sqrt(area / 0.95)), maxWidth);

        // Start with a single empty space, unbounded at the bottom.
        PackRect[] spaces = [PackRect(0, 0, startWidth, 1_000_000)];

        int width = 0;
        int height = 0;

        foreach (ref box; this.boxes) {
            // Look through spaces backwards so that we check smaller spaces first.
            for (int i = cast(int)(spaces.length) - 1; i >= 0; i--) {

                PackRect space = spaces[i];

                // look for empty spaces that can accommodate the current box
                if (box.w > space.w || box.h > space.h) {
                    continue;
                }

                // found the space; add the box to its top-left corner
                // |-------|-------|
                // |  box  |       |
                // |_______|       |
                // |         space |
                // |_______________|

                box.x = space.x;
                box.y = space.y;

                height = max(height, box.y + box.h);
                width = max(width, box.x + box.w);

                if (box.w == space.w && box.h == space.h) {
                    // space matches the box exactly; remove it
                    const last = spaces[(spaces.length) - 1];
                    spaces.popBack();
                    if (i < spaces.length)
                        spaces[i] = last;

                } else if (box.h == space.h) {
                    // space matches the box height; update it accordingly
                    // |-------|---------------|
                    // |  box  | updated space |
                    // |_______|_______________|
                    space.x += box.w;
                    space.w -= box.w;

                    spaces[i] = space;

                } else if (box.w == space.w) {
                    // space matches the box width; update it accordingly
                    // |---------------|
                    // |      box      |
                    // |_______________|
                    // | updated space |
                    // |_______________|
                    space.y += box.h;
                    space.h -= box.h;

                    spaces[i] = space;

                } else {
                    // otherwise the box splits the space into two spaces
                    // |-------|-----------|
                    // |  box  | new space |
                    // |_______|___________|
                    // | updated space     |
                    // |___________________|

                    auto blah = PackRect(
                        space.x + box.w,
                        space.y,
                        space.w - box.w,
                        box.h);

                    spaces ~= blah;

                    space.y += box.h;
                    space.h -= box.h;

                    spaces[i] = space;

                }

                break;
            }
        }

        canvasWidth = width + padding; // container width
        canvasHeight = height + padding; // container height
    }
}

unittest {
    import std.conv;
    import std.stdio;

    import std.datetime.stopwatch;

    StopWatch sw = StopWatch(AutoStart.yes);

    TexturePacker!string packer = TexturePacker!string(2);

    // Only works with PNG for now.

    //? This is 1_000 textures.
    // foreach (j; 0 .. 100) {
    foreach (uint i; 0 .. 10) {
        // ~ to!string(j)
        packer.pack(to!string(i), "assets/" ~ to!string(i + 1) ~ ".png");
    }
    // }

    packer.finalize("atlas.png");

    // writeln(packer.getCanvasWidth(), " ", packer.getCanvasHeight());

    writeln("took: ", sw.peek.total!"msecs", "ms");

    //? Basically, these tests should look the same for all outputs.

    writeln("=== BEGIN OUTPUT STYLE ===");

    // This is to make sure downcasting in getPositionCustom works.
    struct RectangleTestFloat {
        float x = 0;
        float y = 0;
        float w = 0;
        float h = 0;
    }

    RectangleTestFloat test1 = packer.getRectangle!RectangleTestFloat("1");
    writeln(test1);

    struct RectangleTestDouble {
        float x = 0;
        float y = 0;
        float w = 0;
        float h = 0;
    }

    RectangleTestDouble test2 = packer.getRectangle!RectangleTestDouble("1");
    writeln(test2);

    //? This should never compile.
    // struct RectangleTestWrong {
    //     int x = 0;
    //     float y = 0;
    //     float w = 0;
    //     float h = 0;
    // }
    // RectangleTestWrong test3 = packer.getRectangle!RectangleTestWrong("1");
    // writeln(test3);

    struct TestVec2Float {
        float x = 0;
        float y = 0;
    }

    TexturePoints!TestVec2Float test3 = packer.getTexturePoints!TestVec2Float("1");
    writeln(test3);

    struct TestVec2Double {
        double x = 0;
        double y = 0;
    }

    TexturePoints!TestVec2Double test4 = packer.getTexturePoints!TestVec2Double("1");
    writeln(test4);

    //? This should never compile.
    // struct TestVec2Wrong {
    //     int x = 0;
    //     double y = 0;
    // }
    // TexturePoints!TestVec2Wrong test5 = packer.getTexturePoints!TestVec2Wrong("1");
    // writeln(test5);

    writeln("=== BEGIN REFERENCE STYLE ===");

    RectangleTestFloat test5;
    packer.getRectangle("1", test5);
    writeln(test5);

    RectangleTestDouble test6;
    packer.getRectangle("1", test6);
    writeln(test6);

    //? This should never compile.
    // struct RectangleTestWrong {
    //     int x = 0;
    //     float y = 0;
    //     float w = 0;
    //     float h = 0;
    // }
    // RectangleTestWrong test7;
    // packer.getRectangle("1", test7);
    // writeln(test7);

}
