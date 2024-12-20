package main

import "core:dynlib"
import "core:fmt"
import "core:c/libc"
import "core:os"
import "core:log"
import "core:mem"

GameAPI :: struct {
  lib: dynlib.Library,
  init_window: proc(),
  init: proc(),
  update: proc() -> bool,
  shutdown: proc(),
  shutdown_window: proc(),
  memory: proc() -> rawptr,
  memory_size: proc() -> int,
  hot_reloaded: proc(mem: rawptr),
  force_reload: proc() -> bool,
  force_restart: proc() -> bool,
  modification_time: os.File_Time,
  api_version: int,
}

main :: proc() {
  context.logger = log.create_console_logger()
  default_allocator := context.allocator
  tracking_allocator: mem.Tracking_Allocator
  mem.tracking_allocator_init(&tracking_allocator, default_allocator)
  context.allocator = mem.tracking_allocator(&tracking_allocator)

  if err := os.make_directory("bin"); err != os.ERROR_NONE {
    if err != os.General_Error.Exist {
      fmt.println("Failed to create bin directory")
      return
    }
  }

  reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
    err := false
    for _, value in a.allocation_map {
      fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
      err = true
    }
    mem.tracking_allocator_clear(a)
    return err
  }

  game_api_version := 0
  game_api, game_api_ok := load_game_api(game_api_version)

  if !game_api_ok {
    fmt.println("Failed to load Game API")
    return
  }

  game_api_version += 1
  game_api.init_window()
  game_api.init()

  old_game_apis := make([dynamic]GameAPI, default_allocator)

  window_open := true
  for window_open {
    window_open = game_api.update()
    force_reload := game_api.force_reload()
    force_restart := game_api.force_restart()
    reload := force_reload || force_restart
    game_dll_mod, game_dll_mod_err := os.last_write_time_by_name("bin/game.dll")

    if game_dll_mod_err == os.ERROR_NONE && game_api.modification_time != game_dll_mod {
      reload = true
    }

    if reload {
      new_game_api, new_game_api_ok := load_game_api(game_api_version)

      if new_game_api_ok {
        force_restart = force_restart || game_api.memory_size() != new_game_api.memory_size()

        if !force_restart {
          append(&old_game_apis, game_api)
          game_memory := game_api.memory()
          game_api = new_game_api
          game_api.hot_reloaded(game_memory)
        } else {
          game_api.shutdown()
          reset_tracking_allocator(&tracking_allocator)

          for &g in old_game_apis {
            unload_game_api(&g)
          }

          clear(&old_game_apis)
          unload_game_api(&game_api)
          game_api = new_game_api
          game_api.init()
        }

        game_api_version += 1
      }
    }

    if len(tracking_allocator.bad_free_array) > 0 {
      for b in tracking_allocator.bad_free_array {
        log.errorf("Bad free at: %v", b.location)
      }
      libc.getchar()
      panic("Bad free detected")
    }

    free_all(context.temp_allocator)
  }

  free_all(context.temp_allocator)
  game_api.shutdown()

  if reset_tracking_allocator(&tracking_allocator) {
    libc.getchar()
  }

  for &g in old_game_apis {
    unload_game_api(&g)
  }

  delete(old_game_apis)

  game_api.shutdown_window()
  unload_game_api(&game_api)
  mem.tracking_allocator_destroy(&tracking_allocator)
}

load_game_api :: proc(api_version: int) -> (api: GameAPI, ok: bool) {
  mod_time, mod_time_error := os.last_write_time_by_name("bin/game.dll")
  if mod_time_error != os.ERROR_NONE {
    fmt.printfln("Failed getting last write time of bin/game.dll, error code: %d", mod_time_error)
    return
  }

  game_dll_name := fmt.tprintf("bin/game_{0}.dll", api_version)
  copy_dll(game_dll_name) or_return

  _, ok = dynlib.initialize_symbols(&api, game_dll_name, "game_", "lib")
  if !ok {
    fmt.printfln("Failed initializing symbols: {0}", dynlib.last_error())
  }

  api.api_version = api_version
  api.modification_time = mod_time
  ok = true
  return
}

unload_game_api :: proc(api: ^GameAPI) {
  if api.lib != nil {
    if !dynlib.unload_library(api.lib) {
      fmt.printfln("Failed unloading lib: {0}", dynlib.last_error())
    }
  }

  dll_path := fmt.tprintf("bin/game_{0}.dll", api.api_version)
  if os.remove(dll_path) != nil {
    fmt.printfln("Failed to remove {0}", dll_path)
  }
}

copy_dll :: proc(path: string) -> bool {
  exit := libc.system(fmt.ctprintf(`copy "bin\game.dll" "%s"`, path))

  if exit != 0 {
    fmt.printfln("Failed to copy bin/game.dll to %s", path)
    return false
  }

  return true
}

// * Make game use good GPU on laptops.
@(export)
NvOptimusEnablement : u32 = 1
@(export)
AmdPowerXpressRequestHighPerformance : i32 = 1
