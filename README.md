# fast_pack
 A fast texture packer for D

This uses an algorithm I call "inverse tetris". It tries to find the best spot, highest on the y axis, and furthest to the left. Compares to existing collision boxes.
The texture packer is also generic! You can use chars, ints, uints, strings, etc as keys!

[This relies on Adam D. Ruppe's awesome image library. Click here to see it.](https://code.dlang.org/packages/arsd-official%3Aimage_files)

[If you want to learn how this works, click here.](https://github.com/jordan4ibanez/fast_pack/blob/main/HowThisWorks.md)

This is written to be modular. For example:
- You can only import the packer and config to turn it into a command line texture folder packer saver if you really want.
- You could just import the packer and pack a font with trim so it looks nice and save it to a png.
- You can create an atlas of letters with a char keyset, export it to an image with trimming and work with it in memory.

This is the texture atlas that the code below saved:

![Fancy texture atlas](https://raw.githubusercontent.com/jordan4ibanez/fast_pack/main/github_assets/imagePack.png)

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
	TexturePacker!string packer = *new TexturePacker!string(config);

    // Now we pack our textures into it
    for (int i = 1; i <= 10; i++) {
        packer.pack("blah" ~ to!string(i), "assets/" ~ to!string(i) ~ ".png");
    }

    // You can save the texture packer as a raw image
    // The image above is what this saves to. It uses the /assets/ textures.
    packer.saveToFile("imagePack.png");

    // That's pretty neat, now let's create a texture atlas of texture atlases!
    TrueColorImage temp = packer.saveToTrueColorImage();

    config.expansionAmount = 200;

    TexturePacker!int superPacker = *new TexturePacker!int(config);

    for (int i = 0; i <= 30; i++) {
        writeln("packing ", i);
        superPacker.pack(i, temp);
    }

    superPacker.saveToFile("imagePackSuper.png");

    /*
    This seems ridiculous! But you could possibly use it to put a char array for
    font rendering, then shift all the values you get from the packer you put it into, 
    by the values from the packer you pulled the texture atlas out of via:
    Rect coords = packer.getTextureCoordinates("blah1");

    Or you use it to work with OpenGL like this:
    Note: This is using Mike Parker's awesome bindbc OpenGL library.
    You can find this here: https://code.dlang.org/packages/bindbc-opengl
    */
    TrueColorImage myTextureAtlas = packer.saveToTrueColorImage();

    GLuint width = myTextureAtlas.width();
    GLuint height = myTextureAtlas.height();
    ubyte[] tempData = myTextureAtlas.imageData.bytes;

    GLuint id = 0;
    glGenTextures(1, &id);
    glBindTexture(GL_TEXTURE_2D, id);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, tempData.ptr);

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

    If you want even more precision, direct pixel location access, you can do this:
    */

    Rect coords = packer.getTextureCoordinates("blah1");

    /*
    This will give you a bunch of extra information on the specific texture as well

    Hopefully this is helpful to you! Enjoy! :D
    */

}
```