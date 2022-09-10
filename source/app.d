import std.stdio;

import texture_packer;
import std.conv: to;

void main() {
    // In this example I am allocating the texture packer onto the heap to clear out the stack
    // *new is optional
	TexturePacker packer = *new TexturePacker();

    for (int i = 1; i <= 10; i++) {
        packer.pack("blah" ~ to!string(i), "assets/" ~ to!string(i) ~ ".png");
    }


    writeln("packer width = ", packer.getWidth());
    writeln("packer height = ", packer.getHeight());

    writeln(packer.getPixel(0,0));

    packer.saveToFile("test.png");

    // Only use the best debug info when testing 
    writeln("it worked");
}
