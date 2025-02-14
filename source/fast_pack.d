module fast_pack;

import gamut;
import gamut.plugins.png;
import std.algorithm.comparison;
import std.algorithm.sorting;
import std.conv;
import std.math.algebraic;
import std.math.rounding;
import std.range;
import std.range.primitives;
import std.stdio;

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

// Not the same as PackRect!
private struct IntegralRectangle {
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;
}

struct TexturePoints(T) {
    T topLeft;
    T bottomLeft;
    T bottomRight;
    T topRight;
}

private struct Pixel {
    ubyte r = 0;
    ubyte g = 0;
    ubyte b = 0;
    ubyte a = 0;
}

// Packer stores as rgba8.
pragma(inline, true)
private void getPixel(const Image* inputTexture, immutable int x, immutable int y, ref Pixel result) {
    // This is written like this to be as fast as possible.
    const ubyte* scan = cast(ubyte*) inputTexture.scanptr(y);
    immutable int inScanX = x * 4;
    result.r = scan[inScanX];
    result.g = scan[inScanX + 1];
    result.b = scan[inScanX + 2];
    result.a = scan[inScanX + 3];
}

// Packer stores as rgba8.
pragma(inline, true)
private void setPixel(Image* inputTexture, immutable int x, immutable int y, ref Pixel pixel) {
    // This is written like this to be as fast as possible.
    ubyte* scan = cast(ubyte*) inputTexture.scanptr(y);
    immutable int inScanX = x * 4;
    scan[inScanX] = pixel.r;
    scan[inScanX + 1] = pixel.g;
    scan[inScanX + 2] = pixel.b;
    scan[inScanX + 3] = pixel.a;
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

    // todo: maybe an integer lookup table if someone asks for it.

    // These two are synchronized.
    Image*[] textures;
    immutable(T)[] keys;

    PackRect[] boxes;
    int atlasWidth = 0;
    int atlasHeight = 0;
    immutable int padding = 0;

public:

    this(int padding) {
        this.padding = padding;
    }

    /// Queue up a texture to be packed with a key to store it with.
    /// Key is used for retrieving Rectangle and Texture point data.
    pragma(inline, true)
    void pack(T key, string textureLocation) {
        this.uploadTexture(key, textureLocation);
        if (key in floatingLookupTable) {
            throw new Error("Tried to overwrite " ~ to!string(key) ~ " during pack");
        }
        //? Allows looking up if key in database.
        floatingLookupTable[key] = FloatingRectangle();
    }

    /// Packs the textures into the atlas.
    /// Then, writes it to disk at outputFileName.
    pragma(inline, true)
    void finalize(string outputFileName) {
        this.potpack();
        this.flushToDisk(outputFileName);
    }

    /// Packs the textures into the atlas.
    /// Then, returns you the ubyte[] of the raw png data.
    /// The data is RGBA ubytes. Stored left to right, top to bottom, no padding.
    // pragma(inline, true)
    // ubyte[] finalizeToMemory() {
    //     this.potpack();
    //     return this.flushToMemory();
    // }

    /// The total width of the atlas.
    int getAtlasWidth() const {
        return atlasWidth;
    }

    /// The total height of the atlas.
    int getAtlasHeight() const {
        return atlasHeight;
    }

    /// Number of textures stored in the atlas.
    ulong getCount() const {
        return textures.length;
    }

    /// Check if packer has an item by this key.
    bool contains(T key) {
        return (key in floatingLookupTable) ? true : false;
    }

    /// This is getting raw xPos, yPos, width, height.
    /// RectangleType must implement (x,y,w,h) as (float or double).
    /// It will be within scale (0.0 - 1.0) of the atlas.
    /// Top to bottom, left to right.
    /// Returns: RectangleType
    pragma(inline, true)
    RectangleType getRectangle(RectangleType)(immutable T key) {
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
    /// RectangleType must implement (x,y,w,h) as (float or double).
    /// It will be within scale (0.0 - 1.0) of the atlas.
    /// Top to bottom, left to right.
    /// Mutates the variable you give it as a ref.
    pragma(inline, true)
    void getRectangle(RectangleType)(immutable T key, ref RectangleType referenceOutput) {
        referenceOutput = getRectangle!RectangleType(key);
    }

    /// This is getting raw 2D points of a rectangle on the atlas.
    /// Vec2Type must implement this(x,y) as (float or double).
    /// It will be within scale (0.0 - 1.0) of the atlas.
    /// Top to bottom, left to right.
    /// Returns: TexturePoints!Vec2Type
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

    /// This is getting raw 2D points of a rectangle on the atlas.
    /// Vec2Type must implement this(x,y) as (float or double).
    /// It will be within scale (0.0 - 1.0) of the atlas.
    /// Top to bottom, left to right.
    /// Mutates the variable you give it as a ref.
    void getTexturePoints(Vec2Type)(immutable T key, ref TexturePoints!Vec2Type referenceOutput) {
        referenceOutput = getTexturePoints!Vec2Type(key);
    }

private:

    // pragma(inline, true)
    // ubyte[] flushToMemory() {
    //     Image atlas = Image(this.atlasWidth, this.atlasHeight);

    //     foreach (const ref PackRect thisBox; boxes) {

    //         immutable ulong indexOf = thisBox.pointingTo;

    //         Image* thisTexture = &this.textures[indexOf];
    //         immutable(T) thisKey = this.keys[indexOf];

    //         immutable int xPos = thisBox.x + this.padding;
    //         immutable int yPos = thisBox.y + this.padding;

    //         immutable int width = thisBox.w - this.padding;
    //         immutable int height = thisBox.h - this.padding;

    //         floatingLookupTable[thisKey] = FloatingRectangle(
    //             cast(double) xPos / cast(double) this.atlasWidth,
    //             cast(double) yPos / cast(double) this.atlasHeight,
    //             cast(double) width / cast(double) this.atlasWidth,
    //             cast(double) height / cast(double) this.atlasHeight
    //         );

    //         foreach (immutable int inImageX; 0 .. width) {
    //             immutable int inAtlasX = inImageX + xPos;

    //             foreach (immutable int inImageY; 0 .. height) {
    //                 immutable int inAtlasY = inImageY + yPos;

    //                 atlas.setPixel(
    //                     inAtlasX,
    //                     inAtlasY,
    //                     thisTexture.getPixel(
    //                         inImageX,
    //                         inImageY
    //                 ));
    //             }
    //         }
    //     }

    //     return atlas.imageData.bytes;
    // }

    pragma(inline, true)
    void flushToDisk(string outputFileName) {
        import std.datetime.stopwatch;

        Image atlas = Image(this.atlasWidth, this.atlasHeight, PixelType.rgba8);

        foreach (const ref PackRect thisBox; boxes) {

            immutable ulong indexOf = thisBox.pointingTo;

            Image* thisTexture = this.textures[indexOf];
            immutable(T) thisKey = this.keys[indexOf];

            immutable int xPos = thisBox.x + this.padding;
            immutable int yPos = thisBox.y + this.padding;

            immutable int width = thisBox.w - this.padding;
            immutable int height = thisBox.h - this.padding;

            floatingLookupTable[thisKey] = FloatingRectangle(
                cast(double) xPos / cast(double) this.atlasWidth,
                cast(double) yPos / cast(double) this.atlasHeight,
                cast(double) width / cast(double) this.atlasWidth,
                cast(double) height / cast(double) this.atlasHeight
            );

            foreach (immutable int inImageY; 0 .. height) {
                immutable int inAtlasY = inImageY + yPos;

                foreach (immutable int inImageX; 0 .. width) {
                    immutable int inAtlasX = inImageX + xPos;

                    Pixel thisPixel;
                    getPixel(thisTexture, inImageX, inImageY, thisPixel);
                    setPixel(&atlas, inAtlasX, inAtlasY, thisPixel);
                }
            }
        }

        assert(atlas.isValid());

        int flags = ENCODE_PNG_COMPRESSION_1 | ENCODE_PNG_FILTER_FAST;

        writeln(flags & ~ENCODE_PNG_FILTER_FAST);
        writeln(((flags & ENCODE_PNG_FILTER_FAST) == ENCODE_PNG_FILTER_FAST));

        if (!atlas.saveToFile(outputFileName, flags)) {
            throw new Error("Writing " ~ outputFileName ~ " failed");
        }
    }

    pragma(inline, true)
    void uploadTexture(T key, string textureLocation) {
        Image* tempTextureObject = new Image();
        tempTextureObject.loadFromFile(textureLocation);

        if (tempTextureObject.type != PixelType.rgba8) {
            tempTextureObject.convertTo(PixelType.rgba8);
        }

        if (!tempTextureObject.isValid()) {
            throw new Error(to!string(key) ~ " is invalid.");
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

        atlasWidth = width + padding; // container width
        atlasHeight = height + padding; // container height
    }
}

unittest {
    import std.conv;
    import std.stdio;

    import std.datetime.stopwatch;

    StopWatch sw = StopWatch(AutoStart.yes);

    TexturePacker!string packer = TexturePacker!string(2);

    //! Only works with PNG for now.
    foreach (uint i; 0 .. 10) {
        packer.pack(to!string(i), "assets/" ~ to!string(i + 1) ~ ".png");
    }

    // Overwrite protection.
    try {
        foreach (uint i; 0 .. 10) {
            packer.pack(to!string(i), "assets/" ~ to!string(i + 1) ~ ".png");
        }
        throw new Error("!!!FAILURE!!!");
    } catch (Error e) {
        if (e.msg == "!!!FAILURE!!!") {
            throw new Error("overwrite protection not functioning!");
        } else {
            writeln("overwrite protection functioning");
        }
    }

    foreach (uint i; 0 .. 10) {
        assert(packer.contains(to!string(i)));
    }
    writeln("contains passed 1");

    packer.finalize("atlas.png");

    foreach (uint i; 0 .. 10) {
        assert(packer.contains(to!string(i)));
    }
    writeln("contains passed 2");

    //     writeln(packer.getAtlasWidth(), " ", packer.getAtlasHeight());

        writeln("took: ", sw.peek.total!"msecs", "ms");

    //     //? Basically, these tests should look the same for all outputs.

    //     writeln("=== BEGIN OUTPUT STYLE ===");

    //     // This is to make sure downcasting in getPositionCustom works.
    //     struct RectangleTestFloat {
    //         float x = 0;
    //         float y = 0;
    //         float w = 0;
    //         float h = 0;
    //     }

    //     RectangleTestFloat test1 = packer.getRectangle!RectangleTestFloat("1");
    //     writeln(test1);

    //     struct RectangleTestDouble {
    //         float x = 0;
    //         float y = 0;
    //         float w = 0;
    //         float h = 0;
    //     }

    //     RectangleTestDouble test2 = packer.getRectangle!RectangleTestDouble("1");
    //     writeln(test2);

    //     //? This should never compile.
    //     // struct RectangleTestWrong {
    //     //     int x = 0;
    //     //     float y = 0;
    //     //     float w = 0;
    //     //     float h = 0;
    //     // }
    //     // RectangleTestWrong test3 = packer.getRectangle!RectangleTestWrong("1");
    //     // writeln(test3);

    //     struct TestVec2Float {
    //         float x = 0;
    //         float y = 0;
    //     }

    //     TexturePoints!TestVec2Float test3 = packer.getTexturePoints!TestVec2Float("1");
    //     writeln(test3);

    //     struct TestVec2Double {
    //         double x = 0;
    //         double y = 0;
    //     }

    //     TexturePoints!TestVec2Double test4 = packer.getTexturePoints!TestVec2Double("1");
    //     writeln(test4);

    //     //? This should never compile.
    //     // struct TestVec2Wrong {
    //     //     int x = 0;
    //     //     double y = 0;
    //     // }
    //     // TexturePoints!TestVec2Wrong test5 = packer.getTexturePoints!TestVec2Wrong("1");
    //     // writeln(test5);

    //     writeln("=== BEGIN REFERENCE STYLE ===");

    //     RectangleTestFloat test5;
    //     packer.getRectangle("1", test5);
    //     writeln(test5);

    //     RectangleTestDouble test6;
    //     packer.getRectangle("1", test6);
    //     writeln(test6);

    //     //? This should never compile.
    //     // RectangleTestWrong test7;
    //     // packer.getRectangle("1", test7);
    //     // writeln(test7);

    //     TexturePoints!TestVec2Float test7;
    //     packer.getTexturePoints!TestVec2Float("1", test7);
    //     writeln(test7);

    //     TexturePoints!TestVec2Double test8;
    //     packer.getTexturePoints!TestVec2Double("1", test8);
    //     writeln(test8);

    //     // ? This should never compile.
    //     // TexturePoints!TestVec2Wrong test9;
    //     // packer.getRectangle("1", test9);
    //     // writeln(test9);

    //     writeln("=== BEGIN GET RECTANGLE ===");

    //     foreach (uint i; 0 .. 10) {
    //         writeln(packer.getRectangle!RectangleTestFloat(to!string(i)));
    //         writeln(packer.getRectangle!RectangleTestDouble(to!string(i)));
    //     }

    //     writeln("=== BEGIN GET TEXTURE POINTS ===");

    //     foreach (uint i; 0 .. 10) {
    //         writeln(packer.getTexturePoints!TestVec2Float(to!string(i)));
    //         writeln(packer.getTexturePoints!TestVec2Double(to!string(i)));
    //     }

    //     packer.flushToMemory();
}
