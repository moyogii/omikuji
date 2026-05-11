wget https://raw.githubusercontent.com/flatpak/flatpak-builder-tools/refs/heads/master/cargo/flatpak-cargo-generator.py

python3 -m venv venv

source venv/bin/activate

pipx install poetry

poetry env activate

pip install aiohttp tomlkit

python3 flatpak-cargo-generator.py Cargo.lock -o cargo-sources.json
