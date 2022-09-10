import std.stdio;

import texture_packer;

void main() {
    // In this example I am allocating the texture packer onto the heap to clear out the stack
    // *new is optional
	TexturePacker packer = *new TexturePacker();

    packer.uploadTexture("assets/5.png");

    // Only use the best debug info when testing 
    writeln("it worked");
}
