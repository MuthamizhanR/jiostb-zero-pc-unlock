#!/data/data/com.termux/files/usr/bin/sh
set -e

echo "[*] Installing Termux dependencies..."
pkg update -y && pkg install -y python git android-tools curl

if [ ! -d "$HOME/sideload-jiostb" ]; then
    echo "[*] Cloning sideload-jiostb for TLS cert chain & Shevery..."
    git clone https://github.com/ilikechocopies/sideload-jiostb.git "$HOME/sideload-jiostb"
fi

echo "[*] Installing 'tv' and 'start' commands globally..."
cp ./unlock.py "$HOME/unlock.py"
cp ./tv "$PREFIX/bin/tv"
chmod +x "$PREFIX/bin/tv"

cat << 'EOF' > "$PREFIX/bin/start"
#!/data/data/com.termux/files/usr/bin/sh
echo "[*] Connecting to your Jio TV Box..."
pkill -f "tv --watchdog" 2>/dev/null || true
nohup tv --watchdog >/dev/null 2>&1 &
tv
EOF
chmod +x "$PREFIX/bin/start"

echo "[*] Starting Standalone CWMP Unlock Server (unlock.py) & TLS Proxy (pass_front.py)..."
pkill -f python 2>/dev/null || true
python "$HOME/unlock.py" &
python "$HOME/sideload-jiostb/tls/pass_front.py"
