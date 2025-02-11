module packer;

import image;
import std.algorithm.comparison;
import std.algorithm.sorting;
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

/**
The TexturePacker struct.
You can add more things in after you finalize. But, you will 
need to finalize again. Also, you'll have to re-upload into
the gpu if it's Vulkan or OpenGL.
*/
struct TexturePacker {
    // private:

    // These two are synchronized.
    immutable(TrueColorImage)[] textures;
    immutable(string)[] keys;

    PackRect[] boxes;
    int canvasWidth = 0;
    int canvasHeight = 0;
    immutable int padding = 0;

public:

    this(int padding) {
        this.padding = padding;
    }

    void pack(string key, string textureLocation) {
        this.uploadTexture(key, textureLocation);
    }

    pragma(inline, true)
    void finalize(string outputFileName) {
        this.potpack();
        this.flushToDisk(outputFileName);
    }

    int getCanvasWidth() {
        return canvasWidth;
    }

    int getCanvasHeight() {
        return canvasHeight;
    }

    // todo: remove this.
    int getPadding() {
        return padding;
    }

private:

    pragma(inline, true)
    void flushToDisk(string outputFileName) {
        TrueColorImage atlas = new TrueColorImage(this.canvasWidth, this.canvasHeight);

        foreach (const ref PackRect thisBox; boxes) {

            immutable ulong indexOf = thisBox.pointingTo;

            immutable TrueColorImage thisTexture = this.textures[indexOf];
            immutable(string) thisKey = this.keys[indexOf];

            immutable int xPos = thisBox.x + this.padding;
            immutable int yPos = thisBox.y + this.padding;

            immutable int width = thisBox.w - this.padding;
            immutable int height = thisBox.h - this.padding;

            // for (int x = thisX; x < thisX + thisWidth; x++) {
            //     for (int y = thisY; y < thisY + thisHeight; y++) {
            //         constructingImage.setPixel(
            //             x,
            //             y,
            //             thisTexture.getPixel(
            //                 x - thisX,
            //                 y - thisY
            //         )
            //         );
            //     }
            // }

        }

    }

    pragma(inline, true)
    void uploadTexture(string key, string textureLocation) {
        immutable TrueColorImage tempTextureObject = loadImageFromFile(textureLocation).getAsTrueColorImage();

        if (tempTextureObject is null) {
            throw new Error(key ~ " is null");
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
