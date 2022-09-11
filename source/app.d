module app;

import std.stdio;
import fast_pack.texture_packer;
import fast_pack.texture_packer_config;
import std.conv: to;


void main() {
    // In this example I am allocating the texture packer and config onto the heap to clear out the stack
    // *new is optional
    TexturePackerConfig config = *new TexturePackerConfig();
    config.showDebugEdge = true;
    config.trim = true;
    config.padding = 2;

    // Testing out autoResize
    config.width = 0;
    config.height = 0;
    config.autoResize = true;

    // We give the texture packer constructer our config.
    // This is optional, but the default canvas size is 400 by 400 pixels.
    // So you might want to make that bigger!
	TexturePacker packer = *new TexturePacker(config);

    // Now we pack our textures into it
    for (int i = 1; i <= 10; i++) {
        packer.pack("blah" ~ to!string(i), "assets/" ~ to!string(i) ~ ".png");
    }

    // You can save the texture packer as a raw image
    // The image above is what this saves to. It uses the /assets/ textures.
    packer.saveToFile("imagePack.png");
}