module resources.texture_packer_config;

import image;

struct TexturePackerConfig {

    // Blank pixel border around each texture
    uint border = 0;
    // The border color. Default is red
    Color borderColor = Color(255,0,0,255);

    /*
     * Trim alpha space out of textures to shrink them
     * This will create a new object in memory for each texture trimmed!
     */
    bool trim = true;

    /*
     * Enables the border debug, with the color specified
     * Please note: This will overwrite the edge pixels in your texture!
     */
    bool showDebugBorder = true;

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
    this(uint border, Color borderColor, bool trim, bool showDebugBorder, uint width, uint height) {
        this.border = border;
        this.borderColor = borderColor;
        this.trim = trim;
        this.showDebugBorder = showDebugBorder;
        this.height = height;
        this.width = width;
    }
}