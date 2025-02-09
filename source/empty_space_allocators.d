module empty_space_allocators;

import rect_structs;
import std.range.primitives;

class default_empty_spaces {
    space_rect[] empty_spaces;

public:
    void remove(const int i) {
        empty_spaces[i] = empty_spaces.back();
        empty_spaces.popBack();
    }

    bool add(const space_rect r) {
        empty_spaces ~= r;
        return true;
    }

    auto get_count() const {
        return empty_spaces.length;
    }

    void reset() {
        empty_spaces = [];
    }

    const auto get(const int i) {
        return empty_spaces[i];
    }
}

// template <int MAX_SPACES>
class static_empty_spaces(MAX_SPACES : int) {
    int count_spaces = 0;
    space_rect[MAX_SPACES] empty_spaces;

public:
    void remove(const int i) {
        empty_spaces[i] = empty_spaces[count_spaces - 1];
        --count_spaces;
    }

    bool add(const space_rect r) {
        if (count_spaces < cast(int)(empty_spaces.size())) {
            empty_spaces[count_spaces] = r;
            ++count_spaces;

            return true;
        }

        return false;
    }

    auto get_count() const {
        return count_spaces;
    }

    void reset() {
        count_spaces = 0;
    }

    const auto get(const int i) {
        return empty_spaces[i];
    }
}
