set -xe

wget https://raw.githubusercontent.com/Blugatroff/diversion/main/diversion.lua -O diversion.lua
wget https://raw.githubusercontent.com/Blugatroff/diversion/main/codes.lua -O codes.lua
wget https://raw.githubusercontent.com/Blugatroff/diversion/main/promise.lua -O promise.lua

cd ~/projects/diversion/
nix develop --command cargo build --release
cp ./target/release/diversion ~/.local/bin/
