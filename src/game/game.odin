package game

import "core:math/linalg"
import "core:fmt"
import rl "vendor:raylib"

GameState :: struct {
  player_pos: rl.Vector2,
  some_number: int,
}

state: ^GameState

PIXEL_WINDOW_HEIGHT :: 180
game_camera :: proc() -> rl.Camera2D {
  w := f32(rl.GetScreenWidth())
  h := f32(rl.GetScreenHeight())

  return {
    zoom = h / PIXEL_WINDOW_HEIGHT,
    target = state.player_pos,
    offset = { w / 2, h / 2 },
  }
}

ui_camera :: proc() -> rl.Camera2D {
  return {
    zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT,
  }
}

update :: proc() {
  input: rl.Vector2

  if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
    input.y += 1
  }
  if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
    input.y -= 1
  }
  if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
    input.x += 1
  }
  if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
    input.x -= 1
  }

  input = linalg.normalize0(input)
  state.player_pos += input * rl.GetFrameTime() * 100
  state.some_number += 1
}

draw :: proc() {
  rl.BeginDrawing()
  {
    rl.ClearBackground({ 10, 10, 10, 255})

    rl.BeginMode2D(game_camera())
    {
      rl.DrawRectangleV(state.player_pos, { 10, 20 }, rl.WHITE)
      rl.DrawRectangleV({ 20, 20 }, { 10, 10 }, rl.RED)
      rl.DrawRectangleV({ -30, -20 }, { 10, 10 }, rl.YELLOW)
    }
    rl.EndMode2D()

    rl.BeginMode2D(ui_camera())
    {
      rl.DrawText(fmt.ctprintf("some_number: %v\nplayer_pos: %v", state.some_number, state.player_pos), 5, 5, 8, rl.WHITE)
    }
    rl.EndMode2D()
  }
  rl.EndDrawing()
}
