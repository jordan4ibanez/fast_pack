module finders_interface;

public import best_bin_finder;
public import empty_spaces;
public import rect_structs;
import std.algorithm.sorting;

struct output_rect_type;

class empty_spaces_type(T);

alias output_rect_t = empty_spaces_type;

struct finder_input(F, G) {
    const int max_bin_side;
    const int discard_step;
    F handle_successful_insertion;
    G handle_unsuccessful_insertion;
    const flipping_option flipping_mode;
}

auto make_finder_input(F, G)(
    const int max_bin_side,
    const int discard_step,
    ref F handle_successful_insertion,
    ref G handle_unsuccessful_insertion,
    const flipping_option flipping_mode
) {
    return finder_input!(F, G)(
        max_bin_side,
        discard_step,
        handle_successful_insertion,
        handle_unsuccessful_insertion,
        flipping_mode
    );
}

/*
	Finds the best packing for the rectangles,
	just in the order that they were passed.
*/

rect_wh find_best_packing_dont_sort(empty_spaces_type, F, G)(
    ref output_rect_t!empty_spaces_type[] subjects,
    const ref finder_input!(F, G) input
) {
    // alias order_type = subjects;

    return find_best_packing_impl(
        (auto callback) { callback(subjects); },
        input
    );
}

/*
	Finds the best packing for the rectangles.
	Accepts a list of predicates able to compare two input rectangles.
    
	The function will try to pack the rectangles in all orders generated by the predicates,
	and will only write the x, y coordinates of the best packing found among the orders.
*/

rect_wh find_best_packing(empty_spaces_type, F, G, Comparator, Comparators...)(
    ref output_rect_t!empty_spaces_type[] subjects,
    const ref finder_input!(F, G) input,

    Comparator comparator,
    Comparators comparators...
) {
    alias rect_type = output_rect_t!empty_spaces_type;
    alias order_type = rect_type*[];

    static auto count_orders = 1 + Comparators.length;
    static order_type[count_orders] orders;

    {
        /* order[0] will always exist since this overload requires at least one comparator */
        auto ref initial_pointers = orders[0];
        initial_pointers.clear();

        foreach (ref s; subjects) {
            if (s.area() > 0) {
                initial_pointers.emplace_back(&s);
            }
        }

        for (size_t i = 1; i < count_orders; ++i) {
            orders[i] = initial_pointers;
        }
    }

    size_t f = 0;

    auto ref orders_ref = orders;

    auto make_order = (auto ref predicate) {
        sort(orders_ref[f].begin(), orders_ref[f].end(), predicate);
        ++f;
    };

    make_order(comparator);
    make_order(comparators);

    return find_best_packing_impl < empty_spaces_type, order_type > (
        (auto callback) {
        foreach (ref o; orders_ref) {
            callback(o);
        }
    },
        input
    );
}

/*
	Finds the best packing for the rectangles.
	Provides a list of several sensible comparison predicates.
*/

rect_wh find_best_packing(empty_spaces_type, F, G)(
    ref output_rect_t!empty_spaces_type[] subjects,
    const ref finder_input!(F, G) input
) {
    alias rect_type = output_rect_t!empty_spaces_type;

    return find_best_packing!empty_spaces_type(
        subjects,
        input,

        (const rect_type* a, const rect_type* b) { return a.area() > b.area(); },
        (const rect_type* a, const rect_type* b) {
        return a.perimeter() > b.perimeter();
    },
        (const rect_type* a, const rect_type* b) {
        return max(a.w, a.h) > max(b.w, b.h);
    },
        (const rect_type* a, const rect_type* b) { return a.w > b.w; },
        (const rect_type* a, const rect_type* b) { return a.h > b.h; }
    );
}
