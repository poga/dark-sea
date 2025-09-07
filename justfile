# Run GUT unit tests
test:
    @echo "Running GUT tests..."
    /Applications/Godot.app/Contents/MacOS/Godot --headless --script res://addons/gut/gut_cmdln.gd -gdir=res://core/tests -gexit

build-web:
    mkdir -p build
    /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --headless --export-release "Web" build/index.html
    cd build && zip -r ../build.zip .
