// This file is compiled as part of the `odin.dll` file. It contains the
// procs that `game_hot_reload.exe` will call, such as:
//
// game_init: Sets up the game state
// game_update: Run once per frame
// game_shutdown: Shuts down game and frees memory
// game_memory: Run just before a hot reload, so game.exe has a pointer to the
//		game's memory.
// game_hot_reloaded: Run after a hot reload so that the `g_mem` global variable
//		can be set to whatever pointer it was in the old DLL.
//
// Note: When compiled as part of the release executable this whole package is imported as a normal
// odin package instead of a DLL.

package game

import rl "vendor:raylib"

@(export)
game_update :: proc() -> bool {
  update()
  draw()
  return !rl.WindowShouldClose()
}

@(export)
game_init_window :: proc() {
  rl.SetConfigFlags({ .WINDOW_RESIZABLE, .MSAA_4X_HINT })
  rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
  rl.SetWindowPosition(200, 200)
  rl.SetTargetFPS(500)
}

@(export)
game_init :: proc() {
  state = new(GameState)
  state^ = GameState {
    some_number = 100,
  }

  game_hot_reloaded(state)
}

@(export)
game_shutdown :: proc() {
  free(state)
}

@(export)
game_shutdown_window :: proc() {
  rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
  return state
}

@(export)
game_memory_size :: proc() -> int {
  return size_of(GameState)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
  state = (^GameState)(mem)
}

@(export)
game_force_reload :: proc() -> bool {
  return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
  return rl.IsKeyPressed(.F6)
}
