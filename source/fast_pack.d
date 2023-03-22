/**
* A fast texture packer for D.
*/
module fast_pack;

import std.stdio;

import image;
import std.algorithm.sorting;
import std.algorithm.mutation;
import std.algorithm.iteration;
import std.range;
import std.parallelism;


/**
* AABB bounding box for textures
*/
class Rect {

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
* A double based struct to directly map textures to vertices in your rendering api.
* This has different variables because it is easier to understand when mapping textures
*/
struct TextureRectangle {
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
* The configuration for the texture packer with defaults
* Please note: The fields in this structure are left public so you can create a blank slate
* with defaults, then piecemeal your changes in if you don't like the defaults!
*/
class TexturePackerConfig {


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
    * Default is: nothing
    */
    Color edgeColor = *new Color(0,0,0,255);

    /**
    * The blank space border.
    * Default is nothing
    */
    Color blankSpaceColor = *new Color(0,0,0,0);

    /** 
    * Enables the auto resizer algorithm. This will expand the canvas when it runs out of room.
    * You can combine this with a starting width and height of the canvas to your liking!
    * Default is: true

    //! This is now deprecated
    */
    // bool autoResize = true;
    
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
 * Internally handles free position slots
 */
private struct FreeSlot {
    uint x = 0;
    uint y = 0;
}

/**
* The texture packer structure. Can also be allocated to heap via:
* TexturePacker blah = *new TexturePacker();
* This works as a static component, component system
*/
struct TexturePacker(T) {
    
    /// Maintains the current ID that will be created for collision boxes
    private uint currentID = 0;

    /// The configuration of the texture packer
    private TexturePackerConfig config = new TexturePackerConfig();

    // Holds the keys for the textures, hashmap for faster index retreival
    private uint[T] keys;

    /// This holds the collision boxes of the textures
    private uint[] positionX;
    private uint[] positionY;
    private uint[] boxWidth;
    private uint[] boxHeight;

    /// This holds the actual texture data
    private TrueColorImage[] textures;

    // Free slots for the next texture to be packed into
    private uint[] availableX = [0];
    private uint[] availableY = [0];

    /// The current width of the canvas
    private uint canvasWidth = 0;

    /// The current height of the canvas
    private uint canvasHeight = 0;

    /// Open positions on the canvas
    // private FreeSlot[] freeSlots = [FreeSlot(0,0)];

    /**
    * A constructor with a predefined configuration
    */
    this(TexturePackerConfig config) {
        this.config = config;
        // this.freeSlots = [FreeSlot(this.config.padding, this.config.padding)];

        this.availableX[0] = this.config.padding;
        this.availableY[0] = this.config.padding;
    }

    /**
    * This allows game developers to add in textures to the texture packer canvas with a generic key and string file location.
    */
    void pack(T key, string fileLocation) {
        /// Automate upload internally
        uint currentIndex = this.uploadTexture(key, fileLocation);

        this.internalPack(currentIndex);

        // writeln(this. positionX, " | ", this.positionY, " | ", this.boxWidth, " | ", this.boxHeight);
        // writeln("size: ", this.canvasWidth, " ", this.canvasHeight);
    }

    /**
    * This allows game developers to add in textures to the texture packer canvas with a generic key and TrueColorImage from memory.
    */
    void pack(T key, TrueColorImage memoryImage) {
        /// Automate upload internally
        uint currentIndex = this.uploadTexture(key, memoryImage);

        this.internalPack(currentIndex);
    }

    /**
    * Internally packs the image from the key provided when it was uploaded
    */
    private void internalPack(uint currentIndex) {

        while(!tetrisPack(currentIndex)) {
            this.config.width  += this.config.expansionAmount;
            this.config.height += this.config.expansionAmount;
        }

        /// Finally, update the canvas's size in memory
        this.updateCanvasSize(currentIndex);
    }        


    /**
    * Internal inverse tetris scan pack with scoring algorithm
    */
    private bool tetrisPack(uint currentIndex) {

        bool found = false;        

        /// Cache padding
        uint padding = this.config.padding;

        uint score = uint.max;

        /// Cache widths
        uint maxX = this.config.width;
        uint maxY = this.config.height;

        uint bestX = padding;
        uint bestY = padding;

        uint thisWidth  = this.boxWidth[currentIndex];
        uint thisHeight = this.boxHeight[currentIndex];
        
        /// Iterate all available positions
        loop: foreach (uint y; this.availableY) {

            if (found) {
                break loop;
            }

            foreach (uint x; this.availableX) {
                uint newScore = x + y;
                if (newScore < score) {
                    /// In bounds check
                    if (x + thisWidth + padding < maxX && y + thisHeight + padding < maxY ) {                    

                        bool failed = false;

                        /// Collided with other box failure
                        /// Index each collision box to check if within

                        for (int i = 0; i < currentIndex; i++) {
                            
                            uint otherX = this.positionX[i];
                            uint otherY = this.positionY[i];
                            uint otherWidth = this.boxWidth[i];
                            uint otherHeight = this.boxHeight[i];

                            // If it found a free slot, first come first plop
                            if (otherX + otherWidth + padding > x  &&
                                otherX <= x + thisWidth + padding  &&
                                otherY + otherHeight + padding > y &&
                                otherY <= y + thisHeight + padding 
                                ) {
                                    failed = true;
                                    break loop;
                            }
                        }

                        if (!failed) {
                            found = true;
                            bestX = x;
                            bestY = y;
                            score = newScore;
                            break loop;
                        }
                    }
                }
            }
        }

        if (!found) {
            return false;
        }

        this.positionX[currentIndex] = bestX;
        this.positionY[currentIndex] = bestY;

        this.availableX ~= bestX + thisWidth + padding;
        this.availableY ~= bestY + thisHeight + padding;

        return true;
    }

    /// Get texture coordinates for working with your graphics api in double floating point precision
    TextureRectangle getTextureCoordinatesDouble(T key) {

        Rect AABB = collisionBoxes[key];

        return FastRect(
             cast(double) AABB.x / cast(double) width,
             cast(double) AABB.y / cast(double) height,
            (cast(double) AABB.x + cast(double) AABB.width) / cast(double) width,
            (cast(double) AABB.y + cast(double) AABB.height) / cast(double) height            
        );
    }

    /// Constructs a memory image of the current canvas
    TrueColorImage saveToTrueColorImage() {
        /// Creates a blank image with the current canvas size
        TrueColorImage constructingImage = new TrueColorImage(this.canvasWidth, this.canvasHeight);

        if (this.config.fastCanvasExport) {
            /// Iterate through all collision boxes and blit the pixels (fast)
            for (uint i = 0; i < this.currentID; i++) {
                TrueColorImage thisTexture = this.textures[i];
                uint thisX = this.positionX[i];
                uint thisY = this.positionY[i];
                uint thisWidth = this.boxWidth[i];
                uint thisHeight = this.boxHeight[i];

                for (int x = thisX; x < thisX + thisWidth; x++) {
                    for (int y = thisY; y < thisY + thisHeight; y++) {
                        constructingImage.setPixel(
                            x,
                            y,
                            thisTexture.getPixel(
                                x - thisX,
                                y - thisY
                            )
                        );
                    }
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
    private void updateCanvasSize(uint currentIndex) {
        uint newRight = this.positionX[currentIndex] + this.boxWidth[currentIndex];
        uint newTop = this.positionY[currentIndex] + this.boxHeight[currentIndex];
        uint padding = this.config.padding;
        if (newRight > this.canvasWidth) {
            this.canvasWidth = newRight + padding;
        }
        if (newTop > this.canvasHeight) {
            this.canvasHeight = newTop + padding;
        }
    }

    /**
    * Uploads a texture into the associative arrays of the texture packer.
    * This allows game developers to handle a lot less boilerplate
    */
    private uint uploadTexture(T key, string fileLocation) {
        TrueColorImage tempTextureObject = loadImageFromFile(fileLocation).getAsTrueColorImage();
        return this.uploadTexture(key, tempTextureObject);
    }

    /**
    * Uploads a texture into the associative arrays of the texture packer.
    * This allows game developers to handle a lot less boilerplate
    */
    private uint uploadTexture(T key, TrueColorImage tempTextureObject) {

        /// Trim it and generate a new trimmed texture
        if (this.config.trim) {
            tempTextureObject = this.trimTexture(tempTextureObject);
        }

        /// Throw exception if something crazy happens
        if (tempTextureObject is null) {
            throw new Exception("An unkown error has occurred on upload!");
        }

        /// Get an AABB of the texture, with specific internally handled ID
        uint id = this.currentID;
        uint posX = 0;
        uint posY = 0;
        uint width = tempTextureObject.width();
        uint height = tempTextureObject.height();

        // Throw exception if the texture size is 0 on x or y axis
        if (width == 0 || height == 0) {
            throw new Exception("Tried to upload a completely transparent texture!");
        }

        currentID++;

        /// Plop it into the internal keys
        this.keys[key]  = id;
        this.positionX ~= posX;
        this.positionY ~= posY;
        this.boxWidth  ~= width;
        this.boxHeight ~= height;
        this.textures  ~= tempTextureObject;

        this.trimAndSortAvailableSlots();

        return id;
    }

    /**
    * Removes duplicates, automatically sorts smallest to biggest
    */
    private void trimAndSortAvailableSlots() {
        this.availableX = this.availableX.sort!((a,b) => a > b ).uniq().retro().array;
        this.availableY = this.availableY.sort!((a,b) => a > b ).uniq().retro().array;        
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

/**
* Simple distance 2d calculator
*/
private uint calculateManhattan(uint x1, uint y1, uint x2, uint y2) {
    return (x1 - x2) + (y1 - y2);
}

unittest {    
    int start = 1;
    import std.stdio;
    import std.conv: to;
    TexturePackerConfig config = new TexturePackerConfig();
    config.trim = true;
    config.padding = 2;
    TexturePacker!string packer = TexturePacker!string(config);

    int testLimiter = 500;

    TrueColorImage[] textures = new TrueColorImage[10];
    for (uint i = 0; i < 10; i++) {
        textures[i] = loadImageFromFile("assets/" ~ to!string(i + 1) ~ ".png").getAsTrueColorImage();
    }

    for(int i = start; i <= testLimiter; i++){
        writeln(i);
        int value = ((i - 1) % 10);
        packer.pack("blah" ~ to!string(i),textures[value]);
    }
    packer.saveToFile("newTest.png");
}