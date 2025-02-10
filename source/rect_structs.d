module rect_structs;

import std.algorithm.mutation;

alias total_area_type = int;
alias space_rect = rect_xywh;

struct rect_wh {

    int w = 0;
    int h = 0;

    this(const int w, const int h) {
        this.w = w;
        this.h = h;
    }

    auto ref flip() {
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

    void expand_with(R)(const ref R r) {
        w = max(w, r.x + r.w);
        h = max(h, r.y + r.h);
    }
}

struct rect_xywh {
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;

    this(const int x, const int y, const int w, const int h) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
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
}

struct rect_xywhf {
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;
    bool flipped = false;

    this(const int x, const int y, const int w, const int h, const bool flipped) {
        this.x = x;
        this.y = y;

        this.w = flipped ? h : w;
        this.h = flipped ? w : h;

        this.flipped = flipped;

    }

    this(const ref rect_xywh b) {
        this = rect_xywhf(b.x, b.y, b.w, b.h, false);
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
}
