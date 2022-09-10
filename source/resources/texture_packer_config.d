module resources.texture_packer_config;

struct TexturePackerConfig {

    // Blank pixel border around each texture
    uint border = 0;
    // The border color. Default is red
    Color borderColor = new Color(255,0,0,255);

    /*
     * Trim alpha space out of textures to shrink them
     * This will create a new object in memory for each texture trimmed!
     */
    bool trim = false;

    /*
     * Enables the border debug, with the color specified
     * Please note: This will overwrite the edge pixels in your texture!
     */
    bool showDebugBorder = true;

    this(uint border, Color borderColor, bool trim, bool showDebugBorder) {
        this.border = border;
        this.borderColor = borderColor;
        this.trim = trim;
        this.showDebugBorder = showDebugBorder;
    }
}