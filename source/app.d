module app;

import finders_interface;
import std.stdio;

void main() {
    writeln("hi");
    static bool allow_flip = true;
    const auto runtime_flipping_mode = flipping_option.ENABLED;

    /* 
		Here, we choose the "empty_spaces" class that the algorithm will use from now on. 
	
		The first template argument is a bool which determines
		if the algorithm will try to flip rectangles to better fit them.

		The second argument is optional and specifies an allocator for the empty spaces.
		The default one just uses a vector to store the spaces.
		You can also pass a "static_empty_spaces<10000>" which will allocate 10000 spaces on the stack,
		possibly improving performance.
	*/

    // alias spaces_type = empty_spaces(allow_flip, default_empty_spaces);

    /* 
		rect_xywh or rect_xywhf (see src/rect_structs.h), 
		depending on the value of allow_flip.
	*/

    /*
		Note: 

		The multiple-bin functionality was removed. 
		This means that it is now up to you what is to be done with unsuccessful insertions.
		You may initialize another search when this happens.
	*/

    alias functionType = callback_result function(ref rect_xywh blah) pure nothrow @nogc @safe;

    functionType report_successful = (ref rect_xywh blah) {
        return callback_result.CONTINUE_PACKING;
    };

    functionType report_unsuccessful = (ref rect_xywh blah) {
        return callback_result.ABORT_PACKING;
    };

    /*
		Initial size for the bin, from which the search begins.
		The result can only be smaller - if it cannot, the algorithm will gracefully fail.
	*/

    const int max_side = 1000;

    /*
		The search stops when the bin was successfully inserted into,
		AND the next candidate bin size differs from the last successful one by *less* then discard_step.

		The best possible granuarity is achieved with discard_step = 1.
		If you pass a negative discard_step, the algoritm will search with even more granularity -
		E.g. with discard_step = -4, the algoritm will behave as if you passed discard_step = 1,
		but it will make as many as 4 attempts to optimize bins down to the single pixel.

		Since discard_step = 0 does not make sense, the algoritm will automatically treat this case 
		as if it were passed a discard_step = 1.

		For common applications, a discard_step = 1 or even discard_step = 128
		should yield really good packings while being very performant.
		If you are dealing with very small rectangles specifically,
		it might be a good idea to make this value negative.

		See the algorithm section of README for more information.
	*/

    const int discard_step = -4;

    /* 
		Create some arbitrary rectangles.
		Every subsequent call to the packer library will only read the widths and heights that we now specify,
		and always overwrite the x and y coordinates with calculated results.
	*/

    rect_xywh[] rectangles;

    rectangles ~= (rect_xywh(0, 0, 20, 40));
    rectangles ~= (rect_xywh(0, 0, 120, 40));
    rectangles ~= (rect_xywh(0, 0, 85, 59));
    rectangles ~= (rect_xywh(0, 0, 199, 380));
    rectangles ~= (rect_xywh(0, 0, 85, 875));

    auto report_result = (const rect_wh result_size) {
        writeln("Resultant bin: ", result_size.w, " ", result_size.h);

        foreach (const r; rectangles) {
            writeln(r.x, " ", r.y, " ", r.w, " ", r.h);
        }
    };

    {
        /*
			Example 1: Find best packing with default orders. 

			If you pass no comparators whatsoever, 
			the standard collection of 6 orders:
		   	by area, by perimeter, by bigger side, by width, by height and by "pathological multiplier"
			- will be passed by default.
		*/

        finder_input!(functionType, functionType) blah = make_finder_input(
            max_side,
            discard_step,
            report_successful,
            report_unsuccessful,
            runtime_flipping_mode
        );

        // const result_size = find_best_packing(
        //     rectangles,

        // );

        // report_result(result_size);
    }

}
