module texture_packer;

import image;

import resources.rect;
import resources.texture_packer_config;

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
    void uploadTexture(string fileLocation) {
        
    }
}