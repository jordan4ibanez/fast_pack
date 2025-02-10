module app;

import packer;
import raylib;
import std.algorithm.comparison;
import std.random;
import std.stdio;

void main() {

    auto rnd = Random(unpredictableSeed());
    TexturePacker packer = TexturePacker();

    foreach (i; 0 .. 2000) {
        packer.pack(uniform(20, 40, rnd), uniform(20, 40, rnd));
    }

    foreach (i; 0 .. 18_000) {
        packer.pack(uniform(5, 10, rnd), uniform(5, 10, rnd));
    }

    foreach (i; 0 .. 4000) {
        packer.pack(uniform(200, 400, rnd), uniform(200, 400, rnd));
    }

    packer.pack(100, 110);
    packer.pack(100, 100);
    packer.pack(100, 90);

    packer.finalize();

    writeln(packer.canvasWidth, " ", packer.canvasHeight);

    // writeln("======");

    // foreach (box; packer.boxes) {
    //     writeln(box.x, " ", box.y);
    // }

    // writeln(packer.canvasWidth, " ", packer.canvasHeight, " ", packer.canvasFill);

    SetTraceLogLevel(TraceLogLevel.LOG_FATAL);
    // call this before using raylib
    validateRaylibBinding();

    int offset = 10;

    InitWindow(cast(int) min(16_364, packer.canvasWidth) + (offset * 2),
        cast(int) min(16_364, packer.canvasHeight) + (offset * 2), "Hello, Raylib-D!");

    SetTargetFPS(60);
    while (!WindowShouldClose()) {
        BeginDrawing();
        ClearBackground(Colors.BLACK);

        DrawRectangle(offset, offset, packer.canvasWidth, packer.canvasHeight, Colors.WHITE);

        foreach (box; packer.boxes) {
            if (box.x > 16_364 || box.y > 16_364) {
                continue;
            }
            DrawRectangleLines(offset + box.x, offset + box.y, box.w, box.h, Colors.BLACK);
        }

        EndDrawing();
    }
    CloseWindow();
}
