module texture_packer;

import image;

import resources.rect;
import resources.texture_packer_config;

struct TexturePacker {

    TexturePackerConfig config = *new TexturePackerConfig();

    Rectangle[string] collisionBoxes;
    TrueColorImage[string] textures;

    this(TexturePackerConfig config) {
        this.config = config;
    }
}