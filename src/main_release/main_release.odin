package main_release

import "core:log"
import "core:os"

import game "../game"

USE_TRACKING_ALLOCATOR :: #config(USE_TRACKING_ALLOCATOR, false)

main :: proc() {
	mode: int = 0
	when ODIN_OS == .Linux || ODIN_OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}

	logh, logh_err := os.open("bin/log.txt", (os.O_CREATE | os.O_TRUNC | os.O_RDWR), mode)

	if logh_err == os.ERROR_NONE {
		os.stdout = logh
		os.stderr = logh
	}

	logger := logh_err == os.ERROR_NONE ? log.create_file_logger(logh) : log.create_console_logger()
	context.logger = logger

	game.game_init_window()
	game.game_init()

	window_open := true
	for window_open {
		window_open = game.game_update()

		when USE_TRACKING_ALLOCATOR {
			for b in tracking_allocator.bad_free_array {
				log.error("Bad free at: %v", b.location)
			}

			clear(&tracking_allocator.bad_free_array)
		}

		free_all(context.temp_allocator)
	}

	free_all(context.temp_allocator)
	game.game_shutdown()
	game.game_shutdown_window()

	if logh_err == os.ERROR_NONE {
		log.destroy_file_logger(logger)
	}

	when USE_TRACKING_ALLOCATOR {
		for key, value in tracking_allocator.allocation_map {
			log.error("%v: Leaked %v bytes\n", value.location, value.size)
		}

		tracking_allocator_destroy(&tracking_allocator)
	}
}

// * Make game use good GPU on laptops.
@(export)
NvOptimusEnablement: u32 = 1
@(export)
AmdPowerXpressRequestHighPerformance: i32 = 1