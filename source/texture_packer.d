module texture_packer;

import std.stdio;

import image;

import resources.rect;
import resources.texture_packer_config;
import std.typecons: tuple, Tuple;

/*
 * The texture packer structure, can also be allocated to heap via:
 * TexturePacker blah = *new TexturePacker();
 */
struct TexturePacker {

    // The configuration of the texture packer
    TexturePackerConfig config = *new TexturePackerConfig();

    // This holds the collision boxes of the textures
    Rect[string] collisionBoxes;

    // This holds the actual texture data
    TrueColorImage[string] textures;

    /*
     * A constructor with a predefined configuration
     */
    this(TexturePackerConfig config) {
        this.config = config;
    }

    /*
     * Uploads a texture into the associative arrays of the texture packer.
     * This allows game developers to handle a lot less boilerplate
     */
    Tuple!(Rect, TrueColorImage) uploadTexture(string fileLocation) {
        TrueColorImage tempTextureObject = loadImageFromFile(fileLocation).getAsTrueColorImage();

        // Trim it and generate a new trimmed texture
        if (this.config.trim) {
            writeln("trimmed");
            tempTextureObject = this.trimTexture(tempTextureObject);
        }

        // Get an AABB of the texture
        Rect AABB = Rect(0,0,tempTextureObject.width(), tempTextureObject.height());

        // Throw exception if the texture size is 0 on x or y axis
        if (AABB.width == 0 || AABB.height == 0) {
            throw new Exception("Tried to upload a completely transparent texture!");
        }


        // Return both data types
        return tuple(AABB, tempTextureObject);
    }

    /*
     * Trims and creates a new texture in memory, then returns it
     */
    TrueColorImage trimTexture(TrueColorImage untrimmedTexture) {

        uint textureWidth = untrimmedTexture.width();
        uint textureHeight = untrimmedTexture.height();

        uint minX = 0;

        // Scan rows for alpha
        for (int x = 0; x < textureWidth; x++) {
            bool found = false;
            for (int y = 0; y < textureHeight; y++) {
                if (untrimmedTexture.getPixel(x,y).a > 0) {
                    minX = x;
                    found = true;
                    break;
                }
            }
            if (found) {
                break;
            }
        }

        uint maxX = 0;

        // Scan rows for alpha
        for (int x = textureWidth - 1; x >= 0; x--) {
            bool found = false;
            for (int y = 0; y < textureHeight; y++) {
                if (untrimmedTexture.getPixel(x,y).a > 0) {
                    maxX = x + 1;
                    found = true;
                    break;
                }
            }
            if (found) {
                break;
            }
        }

        uint minY = 0;

        // Scan columns for alpha
        for (int y = 0; y < textureHeight; y++) {
            bool found = false;
            for (int x = 0; x < textureWidth; x++) {
                if (untrimmedTexture.getPixel(x,y).a > 0) {
                    minY = y;
                    found = true;
                    break;
                }
            }
            if (found) {
                break;
            }
        }

        uint maxY = 0;

        // Scan columns for alpha
        for (int y = textureHeight - 1; y >= 0; y--) {
            bool found = false;
            for (int x = 0; x < textureWidth; x++) {
                if (untrimmedTexture.getPixel(x,y).a > 0) {
                    maxY = y + 1;
                    found = true;
                    break;
                }
            }
            if (found) {
                break;
            }
        }

        // Create a new texture with trimmed size

        uint newSizeX = maxX - minX;
        uint newSizeY = maxY - minY;

        TrueColorImage trimmedTexture = new TrueColorImage(newSizeX, newSizeY);

        // Blit the old pixels into the new texture with modified location

        for (uint x = 0; x < newSizeX; x++) {
            for (uint y = 0; y < newSizeY; y++) {
                trimmedTexture.setPixel(x,y, untrimmedTexture.getPixel(x + minX, y + minY));
            }
        }

        return trimmedTexture;
    }
}