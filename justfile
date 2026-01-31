# Run GUT unit tests
test:
    @echo "Running GUT tests..."
    /Applications/Godot.app/Contents/MacOS/Godot --headless --script res://addons/gut/gut_cmdln.gd -gdir=res://core/tests -gexit

# Validate Godot project - checks imports and script parsing
check:
    #!/usr/bin/env bash
    set -euo pipefail
    output=$(/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . 2>&1)
    if echo "$output" | grep -q "ERROR"; then
        echo "$output" | grep -E "(ERROR|SCRIPT ERROR)"
        exit 1
    fi
    echo "Project validates successfully"

build-web:
    mkdir -p build/web
    /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --headless --export-release "Web" build/webindex.html
    cd build/web && zip -r ../web.zip .

build-mac:
	mkdir -p build/mac
	/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --headless --export-release "macOS" build/mac/game.app
	cd build/mac && zip -r ../mac.zip .

build-linux:
	mkdir -p build/linux
	/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --headless --export-release "Linux" build/linux/game.x86_64
	cd build/linux && zip -r ../linux.zip .

build-windows:
	mkdir -p build/windows
	/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --headless --export-release "Windows Desktop" build/windows/game.exe
	cd build/windows && zip -r ../windows.zip .

