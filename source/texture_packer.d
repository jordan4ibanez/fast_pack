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
    private TexturePackerConfig config = *new TexturePackerConfig();

    // This holds the collision boxes of the textures
    private Rect[string] collisionBoxes;

    // This holds the actual texture data
    private TrueColorImage[string] textures;

    /*
     * A constructor with a predefined configuration
     */
    this(TexturePackerConfig config) {
        this.config = config;
    }

    /*
     * This allows game developers to tell the texture packer what to upload as simply as possible
     */
    void pack(string key, string fileLocation) {

        // Automate upload internally
        this.uploadTexture(key, fileLocation);

        // Throw exception if key is not in the internal library
        if (!(key in this.collisionBoxes)) {
            throw new Exception("Something has gone wrong getting collision box from internal library!");   
        }

        // Grab the AABB. ( Note: Not a direct dictionary object reference )
        Rect AABB = this.collisionBoxes[key];

        
        
    }

    void debugIt(string key) {
        writeln(this.collisionBoxes[key]);
    }

    /*
     * Uploads a texture into the associative arrays of the texture packer.
     * This allows game developers to handle a lot less boilerplate
     */
    private void uploadTexture(string key, string fileLocation) {
        TrueColorImage tempTextureObject = loadImageFromFile(fileLocation).getAsTrueColorImage();

        // Trim it and generate a new trimmed texture
        if (this.config.trim) {
            tempTextureObject = this.trimTexture(tempTextureObject);
        }

        // Get an AABB of the texture
        Rect AABB = Rect(0,0,tempTextureObject.width(), tempTextureObject.height());

        // Throw exception if the texture size is 0 on x or y axis
        if (AABB.width == 0 || AABB.height == 0) {
            throw new Exception("Tried to upload a completely transparent texture!");
        }

        // Throw exception if something crazy happens
        if (tempTextureObject is null) {
            throw new Exception("An unkown error has occurred on upload!");
        }

        // Plop it into the internal keys
        this.collisionBoxes[key] = AABB;
        this.textures[key] = tempTextureObject;

    }

    /*
     * Trims and creates a new texture in memory, then returns it
     */
    private TrueColorImage trimTexture(TrueColorImage untrimmedTexture) {

        // This is basically the worlds lamest linear 2d voxel raycast

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