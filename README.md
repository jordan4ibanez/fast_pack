# fast_pack
 A fast texture packer for D

This uses an algorithm I call "inverse tetris". It tries to find the best spot, highest on the y axis, and furthest to the left. It does this pixel by pixel going upwards instead of downwards, hence why it is called inverse tetris.

This relies on ADR's awesome image library: https://code.dlang.org/packages/arsd-official%3Aimage_files

Here is a simple tutorial on how to use it:

```d
import std.stdio;
import fast_pack.texture_packer;
import fast_pack.texture_packer_config;
import fast_pack.rect;
import std.conv: to;
import image;

void main() {

    // In this example I am allocating the texture packer and config onto the heap to clear out the stack
    // *new is optional
    TexturePackerConfig config = *new TexturePackerConfig();
    config.showDebugEdge = true;
    config.trim = true;
    config.padding = 2;

    // We give the texture packer constructer our config.
    // This is optional, but the default canvas size is 400 by 400 pixels.
    // So you might want to make that bigger!
	TexturePacker packer = *new TexturePacker(config);

    // Now we pack our textures into it
    for (int i = 1; i <= 10; i++) {
        packer.pack("blah" ~ to!string(i), "assets/" ~ to!string(i) ~ ".png");
    }

    // You can save the texture packer as a raw image
    // The image below is what this saves to. It uses the /assets/ textures.
    packer.saveToFile("imagePack.png");

    // Or you use it to work with OpenGL like so
    // (This is using Mike's awesome bindbc OpenGL library)
    TrueColorImage myTextureAtlas = packer.saveToTrueColorImage();

    /*
    GLuint width = myTextureAtlas.width();
    GLuint height = myTextureAtlas.height();
    ubyte[] tempData = myTextureAtlas.imageData.bytes;

    GLuint id = 0;
    glGenTextures(1, &id);
    glBindTexture(GL_TEXTURE_2D, id);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, tempData.ptr);
    */

    /*

    So on and so forth

    If you are asking "How can I even use this to map my textures to my vertices??"

    Well I'm so glad you asked! This comes with two additional internal types:

    GLRectDouble
    GLRectFloat

    These are part of the fast_pack.rect import

    Their names specify their precision and size

    Let's get the texture coordinates of...."blah3" in double precision!

    */

    GLRectDouble myTextureCoordinates = packer.getTextureCoordinatesDouble("blah3");

    // Now let's get it as a float!

    GLRectFloat myTextureCoordinatesNotSoPrecise = packer.getTextureCoordinatesFloat("blah3");


    // We can work with these like so:

    double minX = myTextureCoordinates.minX;
    double maxY = myTextureCoordinates.maxY;

    /*
    
    So on and so forth

    Hopefully this is helpful to you! Enjoy! :D

    */

}
```