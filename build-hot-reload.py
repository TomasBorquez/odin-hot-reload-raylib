import os
import sys
import glob
import shutil
import subprocess
from pathlib import Path

def check_game_running(exe_name):
    try:
        output = subprocess.check_output(['tasklist', '/NH', '/FI', f'IMAGENAME eq {exe_name}'])
        return exe_name.lower() in output.decode('utf-8').lower()
    except subprocess.CalledProcessError:
        return False

def get_odin_root():
    try:
        result = subprocess.run(['odin', 'root'], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    except subprocess.CalledProcessError:
        pass
    return None

def ensure_bin_directory():
    bin_dir = Path("bin")
    if not bin_dir.exists():
        bin_dir.mkdir()
    return bin_dir

def clean_files(pdbs_dir):
    bin_dir = ensure_bin_directory()
    for dll in glob.glob(str(bin_dir / "game_*.dll")):
        try:
            os.remove(dll)
        except OSError as e:
            print(f"Error removing {dll}: {e}")

    if not pdbs_dir.exists():
        pdbs_dir.mkdir()
        with open(pdbs_dir / "pdb_number", "w") as f:
            f.write("0")
        return

    for pdb in pdbs_dir.glob("*.pdb"):
        try:
            os.remove(pdb)
        except OSError as e:
            print(f"Error removing {pdb}: {e}")

    with open(pdbs_dir / "pdb_number", "w") as f:
        f.write("0")

def build_game_dll(pdb_number, bin_dir):
    print("Building game.dll")
    dll_build = subprocess.run([
        'odin', 'build', './src/game',
        '-strict-style', '-vet', '-debug',
        '-define:RAYLIB_SHARED=true',
        '-build-mode:dll',
        f'-out:{bin_dir}/game.dll',
        f'-pdb-name:pdbs/game_{pdb_number}.pdb'
    ], capture_output=True)

    if dll_build.returncode != 0:
        print("Error building game.dll:")
        print(dll_build.stderr.decode())
        sys.exit(1)

def build_game_exe(exe_name, bin_dir):
    print(f"Building {exe_name}")
    exe_build = subprocess.run([
        'odin', 'build', './src/hot_reload',
        '-strict-style', '-vet', '-debug',
        f'-out:{bin_dir}/{exe_name}'
    ], capture_output=True)

    if exe_build.returncode != 0:
        print(f"Error building {exe_name}:")
        print(exe_build.stderr.decode())
        sys.exit(1)

def handle_raylib(bin_dir):
    raylib_path = bin_dir / "raylib.dll"
    if raylib_path.exists():
        return

    odin_root = get_odin_root()
    if not odin_root:
        print("Could not determine Odin root directory")
        sys.exit(1)

    odin_raylib_path = Path(odin_root) / "vendor" / "raylib" / "windows" / "raylib.dll"
    if not odin_raylib_path.exists():
        print(f"Please copy raylib.dll from <your_odin_compiler>/vendor/raylib/windows/raylib.dll to {bin_dir}")
        sys.exit(1)

    print(f"raylib.dll not found in bin directory. Copying from {odin_raylib_path}")
    shutil.copy(odin_raylib_path, raylib_path)

def main():
    EXE_NAME = "game_hot_reload.exe"
    bin_dir = ensure_bin_directory()
    game_running = check_game_running(EXE_NAME)
    pdbs_dir = Path("pdbs")

    if not game_running:
        clean_files(pdbs_dir)

    with open("pdbs/pdb_number", "r") as f:
        pdb_number = int(f.read().strip())

    pdb_number += 1
    with open("pdbs/pdb_number", "w") as f:
        f.write(str(pdb_number))

    build_game_dll(pdb_number, bin_dir)

    if game_running:
        print("Game running, hot reloading...")
        return

    build_game_exe(EXE_NAME, bin_dir)
    handle_raylib(bin_dir)

if __name__ == "__main__":
    main()
