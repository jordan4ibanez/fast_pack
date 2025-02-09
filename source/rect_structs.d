module rect_structs;

import std.algorithm.mutation;

alias total_area_type = int;

struct rect_wh {

    int w = 0;
    int h = 0;

    void rect_wh(int w, int h) {
        this.w = w;
        this.h = h;
    }

    rect_wh flip() {
        swap(w, h);
        return this;
    }

    int max_side() const {
        return h > w ? h : w;
    }

    int min_side() const {
        return h < w ? h : w;
    }

    int area() const {
        return w * h;
    }

    int perimeter() const {
        return 2 * w + 2 * h;
    }

    void expand_with(T)(const T r) {
        w = max(w, r.x + r.w);
        h = max(h, r.y + r.h);
    }
}

struct rect_xywh {
    int x;
    int y;
    int w;
    int h;

    rect_xywh() : x(0), y(0), w(0), h(0) {
    }
    rect_xywh(const int x, const int y, const int w, const int h) : x(x), y(y), w(w), h(h) {
    }

    int area() const {
        return w * h;
    }

    int perimeter() const {
        return 2 * w + 2 * h;
    }

    auto get_wh() const {
        return rect_wh(w, h);
    }
};

struct rect_xywhf {
    int x;
    int y;
    int w;
    int h;
    bool flipped;

    rect_xywhf() : x(0), y(0), w(0), h(0), flipped(false) {
    }
    rect_xywhf(const int x, const int y, const int w, const int h, const bool flipped) : x(x), y(y), w(flipped ? h
            : w), h(flipped ? w : h), flipped(flipped) {
    }
    rect_xywhf(const rect_xywh & b) : rect_xywhf(b.x, b.y, b.w, b.h, false) {
    }

    int area() const {
        return w * h;
    }

    int perimeter() const {
        return 2 * w + 2 * h;
    }

    auto get_wh() const {
        return rect_wh(w, h);
    }
};

using space_rect = rect_xywh;
