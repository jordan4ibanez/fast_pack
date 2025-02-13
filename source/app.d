module app;

import fast_pack;
import std.conv;
import std.stdio;

void main() {

    TexturePacker!string packer = TexturePacker!string(2);

    foreach (uint j; 0 .. 1_00) {
        foreach (uint i; 0 .. 10) {
            packer.pack(to!string(i) ~ " " ~ to!string(j), "assets/" ~ to!string(i + 1) ~ ".png");
        }
    }

    packer.finalize("atlas.png");

    writeln(packer.getAtlasWidth(), " ", packer.getAtlasHeight);

}
