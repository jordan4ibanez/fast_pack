module best_bin_finder;

// import rect_structs;
import finders_interface;
import std.traits;
import std.variant;

enum callback_result {
    ABORT_PACKING,
    CONTINUE_PACKING
}

ref auto dereference(T)(ref T r) {
    /* 
        This will allow us to pass orderings that consist of pointers,
        as well as ones that are just plain objects in a vector.
    */

    static if (isPointer(T)) {
        return *r;
    } else {
        return r;
    }
}

/*
		This function will do a binary search on viable bin sizes,
		starting from the biggest one: starting_bin.

		The search stops when the bin was successfully inserted into,
		AND the bin size to be tried next differs in size from the last viable one by *less* then discard_step.

		If we could not insert all input rectangles into a bin even as big as the starting_bin - the search fails.
		In this case, we return the amount of space (total_area_type) inserted in total.

		If we've found a viable bin that is smaller or equal to starting_bin, the search succeeds.
		In this case, we return the viable bin (rect_wh).
	*/

enum bin_dimension {
    BOTH,
    WIDTH,
    HEIGHT
}

Variant!(total_area_type, rect_wh) best_packing_for_ordering_impl(empty_spaces_type, O)(
    ref empty_spaces_type root,
    O ordering,
    const rect_wh starting_bin,
    int discard_step,
    const bin_dimension tried_dimension
) {
    rect_wh candidate_bin = starting_bin;
    int tries_before_discarding = 0;

    if (discard_step <= 0) {
        tries_before_discarding = -discard_step;
        discard_step = 1;
    }

    //std::cout << "best_packing_for_ordering_impl dim: " << int(tried_dimension) << " w: " << starting_bin.w << " h: " << starting_bin.h << std::endl;

    int starting_step = 0;

    if (tried_dimension == bin_dimension.BOTH) {
        candidate_bin.w /= 2;
        candidate_bin.h /= 2;

        starting_step = candidate_bin.w / 2;
    } else if (tried_dimension == bin_dimension.WIDTH) {
        candidate_bin.w /= 2;
        starting_step = candidate_bin.w / 2;
    } else {
        candidate_bin.h /= 2;
        starting_step = candidate_bin.h / 2;
    }

    for (int step = starting_step;; step = max(1, step / 2)) {
        //std::cout << "candidate: " << candidate_bin.w << "x" << candidate_bin.h << std::endl;

        root.reset(candidate_bin);

        int total_inserted_area = 0;

        const bool all_inserted = () {
            foreach (const ref r; ordering) {
                const ref auto rect = dereference(r);

                if (root.insert(rect.get_wh())) {
                    total_inserted_area += rect.area();
                } else {
                    return false;
                }
            }

            return true;
        }();

        if (all_inserted) {
            /* Attempt was successful. Try with a smaller bin. */

            if (step <= discard_step) {
                if (tries_before_discarding > 0) {
                    tries_before_discarding--;
                } else {
                    return candidate_bin;
                }
            }

            if (tried_dimension == bin_dimension.BOTH) {
                candidate_bin.w -= step;
                candidate_bin.h -= step;
            } else if (tried_dimension == bin_dimension.WIDTH) {
                candidate_bin.w -= step;
            } else {
                candidate_bin.h -= step;
            }

            root.reset(candidate_bin);
        } else {
            /* Attempt ended with failure. Try with a bigger bin. */

            if (tried_dimension == bin_dimension.BOTH) {
                candidate_bin.w += step;
                candidate_bin.h += step;

                if (candidate_bin.area() > starting_bin.area()) {
                    return total_inserted_area;
                }
            } else if (tried_dimension == bin_dimension.WIDTH) {
                candidate_bin.w += step;

                if (candidate_bin.w > starting_bin.w) {
                    return total_inserted_area;
                }
            } else {
                candidate_bin.h += step;

                if (candidate_bin.h > starting_bin.h) {
                    return total_inserted_area;
                }
            }
        }
    }
}

Variant!(total_area_type, rect_wh) best_packing_for_ordering(empty_spaces_type, O)(
    ref empty_spaces_type root,
    ref O ordering,
    const rect_wh starting_bin,
    const int discard_step
) {
    const auto try_pack = (
        const bin_dimension tried_dimension,
        const rect_wh starting_bin
    ) {
        return best_packing_for_ordering_impl(
            root,
            ordering,
            starting_bin,
            discard_step,
            tried_dimension
        );
    };

    const Variant!(total_area_type, rect_wh) best_result = try_pack(bin_dimension.BOTH, starting_bin);

    if (best_result.convertsTo!total_area_type()) {
        return best_result.get!total_area_type();
    }

    auto best_bin = best_result.get!rect_wh();

    auto trial = (const bin_dimension tried_dimension) {
        const Variant!(total_area_type, rect_wh) trial = try_pack(tried_dimension, best_bin);

        if (trial.convertsTo!rect_wh()) {
            best_bin = trial.get!rect_wh();
        }
    };

    trial(bin_dimension.WIDTH);
    trial(bin_dimension.HEIGHT);

    return best_bin;
}

/*
		This function will try to find the best bin size among the ones generated by all provided rectangle orders.
		Only the best order will have results written to.

		The function reports which of the rectangles did and did not fit in the end.
	*/

rect_wh find_best_packing_impl(empty_spaces_type, OrderType, F, I)(F for_each_order, const I input) {
    const auto max_bin = rect_wh(input.max_bin_side, input.max_bin_side);

    OrderType* best_order = nullptr;

    int best_total_inserted = -1;
    auto best_bin = max_bin;

    /* 
			The root node is re-used on the TLS. 
			It is always reset before any packing attempt.
		*/

    static empty_spaces_type root = rect_wh();
    root.flipping_mode = input.flipping_mode;

    for_each_order((ref OrderType current_order) {
        const Variant!(total_area_type, rect_wh) packing = best_packing_for_ordering(
            root,
            current_order,
            max_bin,
            input.discard_step
        );
        if (packing.convertsTo!total_area_type()) {
            const total_area_type total_inserted = packing.get!total_area_type();
            /*
					Track which function inserts the most area in total,
					just in case that all orders will fail to fit into the largest allowed bin.
				*/
            if (best_order == nullptr) {
                if (*total_inserted > best_total_inserted) {
                    best_order = &current_order;
                    best_total_inserted = *total_inserted;
                }
            }
        } else if (packing.convertsTo!rect_wh()) {
            const rect_wh result_bin = packing.get!rect_wh();
            /* Save the function if it performed the best. */
            if (result_bin.area() <= best_bin.area()) {
                best_order = &current_order;
                best_bin = *result_bin;
            }
        }
    }
    );
    {
        assert(best_order != nullptr);

        root.reset(best_bin);

        foreach (ref rr; *best_order) {
            auto ref rect = dereference(rr);

            if (const ret = root.insert(rect.get_wh())) {
                rect = *ret;

                if (callback_result.ABORT_PACKING == input.handle_successful_insertion(
                        rect)) {
                    break;
                }
            } else {
                if (callback_result.ABORT_PACKING == input.handle_unsuccessful_insertion(rect)) {
                    break;
                }
            }
        }

        return root.get_rects_aabb();
    }
}
