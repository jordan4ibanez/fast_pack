module resources.texture_packer_config;

import image;

/*
 * The configuration for the texture packer with (currently debugging) defaults
 */
struct TexturePackerConfig {

    // Blank pixel border padding around each texture
    uint padding = 3;

    // The edge color. Default is red
    Color edgeColor = Color(255,0,0,255);

    // The blank space border. Default is nothing
    Color blankSpaceColor = Color(0,0,0,0);

    /*
     * Trim alpha space out of textures to shrink them
     * This will create a new object in memory for each texture trimmed!
     */
    bool trim = true;

    /*
     * Enables the edge debug, with the color specified
     * Please note: This will overwrite the edge pixels in your texture!
     */
    bool showDebugEdge = true;

    // The width of the texture packer's canvas
    uint width = 400;

    // The height of the texture packer's canvas
    uint height = 400;

    /*
     * Customized constructor
     *
     * Please note: The fields in this structure are left public so you can create a blank slate
     * with defaults, then piecemeal your changes in if you don't like the defaults!
     */
    this(uint padding, Color edgeColor, Color blankSpaceColor, bool trim, bool showDebugEdge, uint width, uint height) {
        this.padding = padding;
        this.edgeColor = edgeColor;
        this.blankSpaceColor = blankSpaceColor;
        this.trim = trim;
        this.showDebugEdge = showDebugEdge;
        this.height = height;
        this.width = width;
    }
}