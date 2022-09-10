module fast_pack.texture_packer;

import std.stdio;

import image;

import fast_pack.rect;
import fast_pack.texture_packer_config;
import std.typecons: tuple, Tuple;
import std.math: sqrt;

/*
 * The texture packer structure, can also be allocated to heap via:
 * TexturePacker blah = *new TexturePacker();
 */
struct TexturePacker {

    // Please note: indexing position actually starts at the top left of the image (0,0)

    // The configuration of the texture packer
    private TexturePackerConfig config = *new TexturePackerConfig();

    // This holds the collision boxes of the textures
    private Rect[string] collisionBoxes;

    // This holds the actual texture data
    private TrueColorImage[string] textures;

    // The current width of the canvas
    private uint width = 0;

    // The current height of the canvas
    private uint height = 0;

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

        // Do a tetris pack bottom right to top left
        tetrisPack(key, AABB);

        // Set the position in the texture packer's dictionary
        this.collisionBoxes[key] = AABB;

        // Finally, update the canvas's size in memory
        this.updateCanvasSize();
    }

    /*
     * Internal pixel by pixel inverse tetris scan with scoring algorithm
     */
    private void tetrisPack(string key, ref Rect AABB) {

        // Start the score at the max value possible for reduction formula
        uint score = uint.max;

        bool found = false;

        // Cache padding
        uint padding = this.config.padding;

        uint goalY = 0;

        // Cache widths
        uint maxX = this.config.width;
        uint maxY = this.config.height;

        uint bestX = uint.max;
        uint bestY = uint.max;

        // Cached fail state
        bool failed = false;

        // 64 bit long to cover uint max
        for (long x = maxX; x >= 0; x--) {
            for (long y = maxY; y >= 0; y--) {

                failed = false;

                AABB.x = cast(uint)x;
                AABB.y = cast(uint)y;

                // out of bounds failure
                if (
                    // Outer
                    AABB.x + AABB.width + padding >= maxX ||
                    AABB.y + AABB.height + padding >= maxY ||
                    // Inner
                    AABB.x < padding ||
                    AABB.y < padding
                    ) {
                    failed = true;
                }

                // Collided with other box failure
                // Index each collision box to check if within
                foreach (data; this.collisionBoxes.byKeyValue()){
                    Rect otherAABB = data.value;
                    if (data.key != key && AABB.collides(otherAABB, padding)) {
                        failed = true;
                        break;
                    }
                }

                // If it successfully found a new position, update the best X and Y
                if (!failed) {
                    uint newScore = AABB.y - goalY;
                    if (newScore <= score) {
                        found = true;
                        score = newScore;
                        bestX = cast(uint)x;
                        bestY = cast(uint)y;
                    }
                }
            }
        }

        if (!found) {
            throw new Exception("Not enough room for texture! Make the packer canvas bigger!");
        }

        AABB.x = bestX;
        AABB.y = bestY;
    }


    /*
     * Get a specific pixel color on the texture's canvas
     */
    Color getPixel(uint x, uint y) {

        // Starts off as blank space
        Color returningColor = this.config.blankSpaceColor;
        
        // Index each collision box to check if within
        foreach (data; this.collisionBoxes.byKeyValue()){

            Rect AABB = data.value;

            if (AABB.containsPoint(x, y)) {
                // Debug outlining texture
                if (this.config.showDebugEdge && AABB.isEdge(x,y)) {
                    returningColor = this.config.edgeColor;
                } else {
                    // Subtract canvas position by AABB position to get the position on the texture
                    returningColor = this.textures[data.key].getPixel(x - AABB.x, y - AABB.y);
                }
                break;
            }
        }

        return returningColor;
    }

    // Constructs a memory image of the current canvas
    TrueColorImage saveToTrueColorImage() {
        // Creates a blank image with the current canvas size
        TrueColorImage constructingImage = new TrueColorImage(width, height);

        // Linear scan the whole canvas, set pixels to constructing image
        for (uint x = 0; x < width; x++) {
            for (uint y = 0; y < height; y++) {
                constructingImage.setPixel(x, y, this.getPixel(x,y));
            }
        }

        return constructingImage;
    }

    // Construct the components of the texture packer into a usable image, then save it to file
    void saveToFile(string fileName) {

        TrueColorImage constructingImage = this.saveToTrueColorImage();

        // Use in asdr built in api to save it to a file for debugging
        writeImageToPngFile(fileName, constructingImage);
    }

    // Update the width of the texture packer's canvas
    void updateCanvasSize() {
        // Iterate through each texture's collision box to see if it's wider than the current calculation
        foreach (Rect collisionBox; this.collisionBoxes) {
            uint newMaxWidth = collisionBox.x + collisionBox.width;
            uint newMaxHeight = collisionBox.y + collisionBox.height;
            if (newMaxWidth > width) {
                width = newMaxWidth + this.config.padding;
            }
            if (newMaxHeight > height) {
                height = newMaxHeight + this.config.padding;
            }
        }
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