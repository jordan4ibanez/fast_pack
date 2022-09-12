/**
 * A fast texture packer for D.
 */

module fast_pack;

import std.stdio;

import image;

import std.typecons: tuple, Tuple;
import std.math: sqrt;
import std.algorithm.sorting: sort;


/**
 * AABB bounding box for textures
 */
struct Rect {
    uint id = 0;
    uint x = 0;
    uint y = 0;
    uint width = 0;
    uint height = 0;

    this(uint id, uint x, uint y, uint width, uint height) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }

    /// AABB point check
    bool containsPoint(uint x, uint y) {
        return x >= this.x && x <= this.x + this.width - 1 && y >= this.y && y <= this.y + this.height - 1;
    }

    /// Check if a point is on the texture's edge
    bool isEdge(uint x, uint y) {
        return x == this.x || x == this.x + this.width - 1 || y == this.y || y == this.y + this.height - 1;
    }

    /// AABB check
    bool collides(Rect AABB, uint padding) {
        return AABB.x + AABB.width + padding - 1 >= this.x &&
                 AABB.x <= this.x + this.width + padding &&
                 AABB.y + AABB.height + padding - 1 >= this.y &&
                 AABB.y <= this.y + this.height + padding;
    }
}

/**
 * A double based struct to directly map textures to vertices in OpenGL
 * This has different variables because it is easier to understand when mapping textures
 */

struct GLRectDouble {
    /// Left
    double minX = 0.0;
    /// Top
    double minY = 0.0;
    /// Right
    double maxX = 0.0;
    /// Bottom
    double maxY = 0.0;
}

/**
 * A float based struct to directly map textures to vertices in OpenGL
 *
 * This has different variables because it is easier to understand when mapping textures
 */
struct GLRectFloat {
    /// Left
    float minX = 0.0;
    /// Top
    float minY = 0.0;
    /// Right
    float maxX = 0.0;
    /// Bottom
    float maxY = 0.0;
}


/**
 * The configuration for the texture packer with defaults
 * Please note: The fields in this structure are left public so you can create a blank slate
 * with defaults, then piecemeal your changes in if you don't like the defaults!
 */
struct TexturePackerConfig {

    /**
     * Enables atlas rebuilds.
     * This only makes a difference if autoResize is enabled.
     * If it is false, the packer will not rebuild the atlas upon canvas expansion.
     * It is faster if disabled, but it will also use more space on the exported texture.
     * Default is: true
     */
    bool atlasRebuilder = true;

    /**
     * Enables fast canvas exporting.
     * If this is enabled edgeColor and blankSpaceColor will be ignored.
     * Default is: true
     */
    bool fastCanvasExport = true;

    /**
     * Blank pixel border padding around each texture
     * Default is: 0;
     */
    uint padding = 0;

    /**
     * The edge color.
     * Default is: red
     */
    Color edgeColor = *new Color(255,0,0,255);

    /**
     * The blank space border.
     * Default is nothing
     */
    Color blankSpaceColor = *new Color(0,0,0,0);

    /** 
     * Enables the auto resizer algorithm. This will expand the canvas when it runs out of room.
     * You can combine this with a starting width and height of the canvas to your liking!
     * Default is: true
     */
    bool autoResize = true;
    
    /**
     * The auto resizer algorithm's resize amount.
     * When the canvas runs out of space, it will expand it by this many pixels.
     * It may have to loop a few times if this is too small to pack a new texture if this is too small.
     * AKA: Too small with thrash it and it will have to continuously rebuild. AKA: Slower
     * Too big and you'll have wasted space, I recommend to experiment with it and print it to png!
     * Default is: 100
     */
    uint expansionAmount = 100;

    /**
     * Trim alpha space out of textures to shrink them
     * This will create a new object in memory for each texture trimmed!
     * Default is: false
     */
    bool trim = false;

    /**
     * Enables the edge debug, with the color specified
     * Please note: This will overwrite the edge pixels in your texture!
     * Default is: false
     */
    bool showDebugEdge = false;

    /**
     * The width of the texture packer's canvas
     * Default is: 400
     */
    uint width = 400;

    /**
     * The height of the texture packer's canvas
     * Default is: 400
     */
    uint height = 400;
}

/**
 * The texture packer structure. Can also be allocated to heap via:
 * TexturePacker blah = *new TexturePacker();
 */
struct TexturePacker(T) {

    /// Please note: indexing position actually starts at the top left of the image (0,0)

    /// Maintains the current ID that will be created for collision boxes
    private uint currentID = 0;

    /// The configuration of the texture packer
    private TexturePackerConfig config = *new TexturePackerConfig();

    /// This holds the collision boxes of the textures
    private Rect[T] collisionBoxes;

    /// This holds the actual texture data
    private TrueColorImage[T] textures;

    /// The current width of the canvas
    private uint width = 0;

    /// The current height of the canvas
    private uint height = 0;

    /**
     * A constructor with a predefined configuration
     */
    this(TexturePackerConfig config) {
        this.config = config;
    }

    /**
     * This allows game developers to add in textures to the texture packer canvas with a generic key and string file location.
     */
    void pack(T key, string fileLocation) {
        /// Automate upload internally
        this.uploadTexture(key, fileLocation);

        this.internalPack(key);
    }

    /**
     * This allows game developers to add in textures to the texture packer canvas with a generic key and TrueColorImage from memory.
     */
    void pack(T key, TrueColorImage memoryImage) {
        /// Automate upload internally
        this.uploadTexture(key, memoryImage);

        this.internalPack(key);
    }

    /*
     * Internally packs the image from the key provided when it was uploaded
     */
    private void internalPack(T key) {

        /// Throw exception if key is not in the internal library
        if (!(key in this.collisionBoxes)) {
            throw new Exception("Something has gone wrong getting collision box from internal library!");   
        }

        /// Do a tetris pack bottom right to top left
        if (this.config.autoResize) {
            while(!tetrisPack(key)) {

                this.config.width  += this.config.expansionAmount;
                this.config.height += this.config.expansionAmount;

                if (this.config.atlasRebuilder) {
                    /// Re-sort all the items out of bounds
                    T[] allKeys;

                    /// Run through in order of insertion
                    uint currentSearch = 0;

                    while(currentSearch < this.currentID) {
                        foreach (T gottenKey; this.collisionBoxes.keys()) {
                            if (this.collisionBoxes[gottenKey].id == currentSearch) {
                                allKeys ~= gottenKey;
                                currentSearch++;
                                /// Only breaks foreach
                                break;
                            }
                        }
                    }

                    // Set the keys out of bounds
                    for (uint i = 0; i < allKeys.length; i++) {
                        this.collisionBoxes[allKeys[i]].x = this.config.width + 1;
                        this.collisionBoxes[allKeys[i]].y = this.config.height + 1;
                    }

                    // Collide them back into the box
                    for (uint i = 0; i < allKeys.length; i++) {
                        T thisKey = allKeys[i];
                        if (key != thisKey) {
                            tetrisPack(thisKey);
                        }
                    }
                }
            }
        } else {
            tetrisPack(key);
        }

        /// Finally, update the canvas's size in memory
        this.updateCanvasSize();
    }

    /**
     * Internal pixel by pixel inverse tetris scan with scoring algorithm
     */
    private bool tetrisPack(T key) {

        /// Grab the AABB out of the internal dictionary
        Rect AABB = this.collisionBoxes[key];

        /// Start the score at the max value possible for reduction formula
        uint score = uint.max;

        bool found = false;

        /// Cache padding
        uint padding = this.config.padding;

        uint goalY = 0;

        /// Cache widths
        uint maxX = this.config.width;
        uint maxY = this.config.height;

        uint bestX = uint.max;
        uint bestY = uint.max;

        /// Cached fail state
        bool failed = false;

        // Iterable positions
        uint[] xPositions;
        uint[] yPositions;

        // Cached collisionboxes
        Rect[] otherCollisionBoxes;

        foreach (gottenData; this.collisionBoxes.byKeyValue()) {
            if (gottenData.key != key) {
                otherCollisionBoxes ~= gottenData.value;
            }
        }

        /// These are the minimum positions (x: 0, y: 0 with 0 padding)
        xPositions ~= padding;
        yPositions ~= padding;

        // Add in all other keys
        foreach (T gottenKey; this.collisionBoxes.keys()) {
            if (gottenKey != key) {
                Rect thisCollisionBox = this.collisionBoxes[gottenKey];
                if (!(thisCollisionBox.width > this.width || thisCollisionBox.y > this.height)) {
                    xPositions ~= thisCollisionBox.x + thisCollisionBox.width + padding;
                    yPositions ~= thisCollisionBox.y + thisCollisionBox.height + padding;
                }
            }
        }

        /// Now sort them max to min, we want to iterate towards the center
        xPositions.sort!("a > b");
        yPositions.sort!("a > b");

        /// Iterate all available positions
        foreach (uint x; xPositions) {
            foreach (uint y; yPositions) {

                failed = false;

                AABB.x = x;
                AABB.y = y;

                /// out of bounds failure
                if (
                    /// Outer
                    AABB.x + AABB.width + padding >= maxX ||
                    AABB.y + AABB.height + padding >= maxY ||
                    /// Inner
                    AABB.x < padding ||
                    AABB.y < padding
                    ) {
                    failed = true;
                }

                /// Collided with other box failure
                /// Index each collision box to check if within
                foreach (otherAABB; otherCollisionBoxes){
                    if (AABB.collides(otherAABB, padding)) {
                        failed = true;
                        break;
                    }
                }

                /// If it successfully found a new position, update the best X and Y
                if (!failed) {
                    uint newScore = AABB.y - goalY;
                    if (newScore <= score) {
                        found = true;
                        score = newScore;
                        bestX = x;
                        bestY = y;
                    }
                }
            }
        }

        if (!found) {
            if (this.config.autoResize) {
                return false;
            } else {
                throw new Exception("Not enough room for texture! Make the packer canvas bigger!");
            }
        }

        AABB.x = bestX;
        AABB.y = bestY;

        // Finally set the collisionbox back into the internal dictionary
        this.collisionBoxes[key] = AABB;

        return true;
    }


    /**
     * Get a specific pixel color on the texture's canvas
     */
    Color getPixel(uint x, uint y) {

        /// Starts off as blank space
        Color returningColor = this.config.blankSpaceColor;
        
        /// Index each collision box to check if within
        foreach (data; this.collisionBoxes.byKeyValue()){

            Rect AABB = data.value;

            if (AABB.containsPoint(x, y)) {
                /// Debug outlining texture
                if (this.config.showDebugEdge && AABB.isEdge(x,y)) {
                    returningColor = this.config.edgeColor;
                } else {
                    /// Subtract canvas position by AABB position to get the position on the texture
                    returningColor = this.textures[data.key].getPixel(x - AABB.x, y - AABB.y);
                }
                break;
            }
        }

        return returningColor;
    }

    /// Get texture coordinates for working with OpenGL with double floating point precision
    GLRectDouble getTextureCoordinatesDouble(T key) {
        Rect AABB = collisionBoxes[key];
        return GLRectDouble(
            cast(double) AABB.x / cast(double) width,
            cast(double) AABB.y / cast(double) height,
            (cast(double) AABB.x + cast(double) AABB.width) / cast(double) width,
            (cast(double) AABB.y + cast(double) AABB.height) / cast(double) height            
        );
    }

    /// Get texture coordinates for working with OpenGL with double floating point precision
    GLRectFloat getTextureCoordinatesFloat(T key) {
        Rect AABB = collisionBoxes[key];
        return GLRectFloat(
            cast(float) AABB.x / cast(float) width,
            cast(float) AABB.y / cast(float) height,
            (cast(float) AABB.x + cast(float) AABB.width) / cast(float) width,
            (cast(float) AABB.y + cast(float) AABB.height) / cast(float) height            
        );
    }

    /// Get texture coordinates in literal uint in case you want to do something custom
    Rect getTextureCoordinates(T key) {
        return collisionBoxes[key];
    }

    /// Constructs a memory image of the current canvas
    TrueColorImage saveToTrueColorImage() {
        /// Creates a blank image with the current canvas size
        TrueColorImage constructingImage = new TrueColorImage(width, height);

        if (this.config.fastCanvasExport) {
            /// Iterate through all collision boxes and blit the pixels (fast)
            T[] keys = this.collisionBoxes.keys();
            for (uint i = 0; i < keys.length; i++) {
                T thisKey = keys[i];
                Rect AABB = this.collisionBoxes[thisKey];
                TrueColorImage thisTexture = this.textures[thisKey];
                for (int x = AABB.x; x < AABB.x + AABB.width; x++) {
                    for (int y = AABB.y; y < AABB.y + AABB.height; y++) {
                        constructingImage.setPixel(
                            x,
                            y,
                            thisTexture.getPixel(
                                x - AABB.x,
                                y - AABB.y
                            )
                        );
                    }
                }
            }

        } else {
            /// Linear scan the whole canvas and collision detect each pixel (slow)
            for (uint x = 0; x < width; x++) {
                for (uint y = 0; y < height; y++) {
                    constructingImage.setPixel(x, y, this.getPixel(x,y));
                }
            }
        }

        return constructingImage;
    }

    /// Construct the components of the texture packer into a usable image, then save it to file
    void saveToFile(string fileName) {

        TrueColorImage constructingImage = this.saveToTrueColorImage();

        /// Use in asdr built in api to save it to a file for debugging
        writeImageToPngFile(fileName, constructingImage);
    }

    /// Update the width of the texture packer's canvas
    private void updateCanvasSize() {
        /// Iterate through each texture's collision box to see if it's wider than the current calculation
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

    /**
     * Uploads a texture into the associative arrays of the texture packer.
     * This allows game developers to handle a lot less boilerplate
     */
    private void uploadTexture(T key, string fileLocation) {
        TrueColorImage tempTextureObject = loadImageFromFile(fileLocation).getAsTrueColorImage();

        /// Trim it and generate a new trimmed texture
        if (this.config.trim) {
            tempTextureObject = this.trimTexture(tempTextureObject);
        }

        /// Get an AABB of the texture, with specific internally handled ID
        Rect AABB = Rect(this.currentID, 0,0,tempTextureObject.width(), tempTextureObject.height());
        currentID++;

        // Throw exception if the texture size is 0 on x or y axis
        if (AABB.width == 0 || AABB.height == 0) {
            throw new Exception("Tried to upload a completely transparent texture!");
        }

        /// Throw exception if something crazy happens
        if (tempTextureObject is null) {
            throw new Exception("An unkown error has occurred on upload!");
        }

        /// Plop it into the internal keys
        this.collisionBoxes[key] = AABB;
        this.textures[key] = tempTextureObject;
    }

    /**
     * Uploads a texture into the associative arrays of the texture packer.
     * This allows game developers to handle a lot less boilerplate
     */
    private void uploadTexture(T key, TrueColorImage memoryImage) {

        /// Trim it and generate a new trimmed texture
        if (this.config.trim) {
            memoryImage = this.trimTexture(memoryImage);
        }

        /// Get an AABB of the texture, with specific internally handled ID
        Rect AABB = Rect(this.currentID, 0,0,memoryImage.width(), memoryImage.height());
        currentID++;

        // Throw exception if the texture size is 0 on x or y axis
        if (AABB.width == 0 || AABB.height == 0) {
            throw new Exception("Tried to upload a completely transparent texture!");
        }

        /// Throw exception if something crazy happens
        if (memoryImage is null) {
            throw new Exception("An unkown error has occurred on upload!");
        }

        /// Plop it into the internal keys
        this.collisionBoxes[key] = AABB;
        this.textures[key] = memoryImage;
    }

    /**
     * Trims and creates a new texture in memory, then returns it
     */
    private TrueColorImage trimTexture(TrueColorImage untrimmedTexture) {

        /// This is basically the worlds lamest linear 2d voxel raycast

        uint textureWidth = untrimmedTexture.width();
        uint textureHeight = untrimmedTexture.height();

        uint minX = 0;

        /// Scan rows for alpha
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

        /// Scan rows for alpha
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

        /// Scan columns for alpha
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

        /// Scan columns for alpha
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

        /// Create a new texture with trimmed size

        uint newSizeX = maxX - minX;
        uint newSizeY = maxY - minY;

        TrueColorImage trimmedTexture = new TrueColorImage(newSizeX, newSizeY);

        /// Blit the old pixels into the new texture with modified location

        for (uint x = 0; x < newSizeX; x++) {
            for (uint y = 0; y < newSizeY; y++) {
                trimmedTexture.setPixel(x,y, untrimmedTexture.getPixel(x + minX, y + minY));
            }
        }

        return trimmedTexture;
    }
}