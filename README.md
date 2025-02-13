# fast_pack
 A fast texture packer for D built on top of potpack.

This is built off of: https://github.com/mapbox/potpack

Translated to D and reworked slightly.

Note: Image trimming has been removed in this version, I didn't use it, I don't think anyone used it.

The implementation has been supercharged and simplified in this version.

**Note:** Only works with PNG (for now).

**NOTE: This is an experimental release!**

The best way I can show you how to use this is by showing you the original unit test at this current point in time.

```d
void main() {
    import std.conv;
    import std.stdio;

    import std.datetime.stopwatch;

    StopWatch sw = StopWatch(AutoStart.yes);

    TexturePacker!string packer = TexturePacker!string(2);

    //! Only works with PNG for now.
    foreach (uint i; 0 .. 10) {
        packer.pack(to!string(i), "assets/" ~ to!string(i + 1) ~ ".png");
    }

    packer.finalize("atlas.png");

    writeln(packer.getAtlasWidth(), " ", packer.getAtlasHeight());

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
    // RectangleTestWrong test7;
    // packer.getRectangle("1", test7);
    // writeln(test7);

    TexturePoints!TestVec2Float test7;
    packer.getTexturePoints!TestVec2Float("1", test7);
    writeln(test7);

    TexturePoints!TestVec2Double test8;
    packer.getTexturePoints!TestVec2Double("1", test8);
    writeln(test8);

    // ? This should never compile.
    // TexturePoints!TestVec2Wrong test9;
    // packer.getRectangle("1", test9);
    // writeln(test9);

    writeln("=== BEGIN GET RECTANGLE ===");

    foreach (uint i; 0 .. 10) {
        writeln(packer.getRectangle!RectangleTestFloat(to!string(i)));
        writeln(packer.getRectangle!RectangleTestDouble(to!string(i)));
    }

    writeln("=== BEGIN GET TEXTURE POINTS ===");

    foreach (uint i; 0 .. 10) {
        writeln(packer.getTexturePoints!TestVec2Float(to!string(i)));
        writeln(packer.getTexturePoints!TestVec2Double(to!string(i)));
    }

    writeln(packer.flushToMemory());
}
```

**Note:** The DUB repo icon is the output of the current unit test modified to use 430 textures.

Here is a development screenshot I found fun. (Running in raylib-d)
![nosey, eh?](https://raw.githubusercontent.com/jordan4ibanez/jordan4ibanez/refs/heads/main/images/image.png)