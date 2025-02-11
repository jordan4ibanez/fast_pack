module app;

import packer;
import raylib;
import std.algorithm.comparison;
import std.random;
import std.stdio;

void main() {

    auto rnd = Random(unpredictableSeed());
    TexturePacker packer = TexturePacker(10);

    foreach (_; 0 .. 1024) {
        packer.pack(uniform(32, 64, rnd), uniform(32, 64, rnd));
    }

    // packer.pack(256, 64);

    packer.finalize();

    writeln(packer.getCanvasWidth(), " ", packer.getCanvasHeight());

    // writeln("======");

    // foreach (box; packer.boxes) {
    //     writeln(box.x, " ", box.y);
    // }

    // writeln(packer.canvasWidth, " ", packer.canvasHeight, " ", packer.canvasFill);

    SetTraceLogLevel(TraceLogLevel.LOG_FATAL);
    // call this before using raylib
    validateRaylibBinding();

    int offset = 10;

    static immutable Color[23] c = [
        Color(200, 200, 200, 255), // Light Gray
        Color(130, 130, 130, 255), // Gray
        Color(80, 80, 80, 255), // Dark Gray
        Color(253, 249, 0, 255), // Yellow
        Color(255, 203, 0, 255), // Gold
        Color(255, 161, 0, 255), // Orange
        Color(255, 109, 194, 255), // Pink
        Color(230, 41, 55, 255), // Red
        Color(190, 33, 55, 255), // Maroon
        Color(0, 228, 48, 255), // Green
        Color(0, 158, 47, 255), // Lime
        Color(0, 117, 44, 255), // Dark Green
        Color(102, 191, 255, 255), // Sky Blue
        Color(0, 121, 241, 255), // Blue
        Color(0, 82, 172, 255), // Dark Blue
        Color(200, 122, 255, 255), // Purple
        Color(135, 60, 190, 255), // Violet
        Color(112, 31, 126, 255), // Dark Purple
        Color(211, 176, 131, 255), // Beige
        Color(127, 106, 79, 255), // Brown
        Color(76, 63, 47, 255), // Dark Brown
        Color(255, 0, 255, 255), // Magenta
        Color(245, 245, 245, 255), // My own White (raylib logo)
    ];

    immutable int padding = packer.getPadding();
    immutable int canvasWidth = packer.getCanvasWidth();
    immutable int canvasHeight = packer.getCanvasHeight();

    InitWindow(cast(int) min(16_364, canvasWidth) + (offset * 2),
        cast(int) min(16_364, canvasHeight) + (offset * 2), "Hello, Raylib-D!");

    SetTargetFPS(60);
    while (!WindowShouldClose()) {
        BeginDrawing();
        ClearBackground(Colors.BLACK);

        DrawRectangle(offset, offset, packer.canvasWidth, packer.canvasHeight, Colors
                .WHITE);

        foreach (i, box; packer.boxes) {
            if (box.x > 16_364 || box.y > 16_364) {
                continue;
            }

            immutable selection = i % c.length;

            writeln(selection);

            DrawRectangle(offset + box.x + padding, offset + box.y + padding, box.w - padding, box.h - padding,
                c[selection]);

            DrawRectangleLines(offset + box.x + padding, offset + box.y + padding, box.w - padding, box.h - padding, Colors
                    .BLACK);
        }

        EndDrawing();
    }
    CloseWindow();
}
