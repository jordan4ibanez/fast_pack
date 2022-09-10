module texture_packer;

import image;
import resources.rectangle;

struct TexturePacker {
    Rectangle[string] collisionBoxes;
    TrueColorImage[string] textures;

    uint border = 0;
    Color borderColor;



}