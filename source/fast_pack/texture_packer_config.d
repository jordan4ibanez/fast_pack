/** 
 * The texture packer configuration struct.
 */
module fast_pack.texture_packer_config;

import image;

/**
 * The configuration for the texture packer with defaults
 *
 * Please note: The fields in this structure are left public so you can create a blank slate
 * with defaults, then piecemeal your changes in if you don't like the defaults!
 */
struct TexturePackerConfig {

    /// Blank pixel border padding around each texture
    uint padding = 0;

    /// The edge color. Default is red
    Color edgeColor = *new Color(255,0,0,255);

    /// The blank space border. Default is nothing
    Color blankSpaceColor = *new Color(0,0,0,0);

    /** 
     * Enables the auto resizer algorithm. This will expand the canvas when it runs out of room.
     * You can combine this with a starting width and height of the canvas to your liking!
     * Default is: false
     */
    bool autoResize = false;
    
    /**
     * The auto resizer algorithm's resize amount.
     * When the canvas runs out of space, it will expand it by this many pixels.
     * It may have to loop a few times if this is too small to pack a new texture if this is too small.
     * AKA: Too small with thrash it and it will have to continuously rebuild. AKA: Slower
     * Too big and you'll have wasted space, I recommend to experiment with it and print it to png!
     * Default is: 50
     */
    uint expansionAmount = 50;

    /**
     * Trim alpha space out of textures to shrink them
     * This will create a new object in memory for each texture trimmed!
     */
    bool trim = false;

    /**
     * Enables the edge debug, with the color specified
     * Please note: This will overwrite the edge pixels in your texture!
     */
    bool showDebugEdge = false;

    /// The width of the texture packer's canvas
    uint width = 400;

    /// The height of the texture packer's canvas
    uint height = 400;

    /**
     * Customized constructor
     * Please note: The fields in this structure are left public so you can create a blank slate
     * with defaults, then piecemeal your changes in if you don't like the defaults!
     */
    this(
        uint padding,
        Color edgeColor,
        Color blankSpaceColor,
        bool autoResize,
        uint expansionAmount,
        bool trim,
        bool showDebugEdge,
        uint width,
        uint height ) {

        this.padding = padding;
        this.edgeColor = edgeColor;
        this.blankSpaceColor = blankSpaceColor;
        this.autoResize = autoResize;
        this.expansionAmount = expansionAmount;
        this.trim = trim;
        this.showDebugEdge = showDebugEdge;
        this.height = height;
        this.width = width;

    }
}