#!/data/data/com.termux/files/usr/bin/sh
STB_IP="$1"
if [ -z "$STB_IP" ]; then
    echo "Usage: ./post_unlock.sh <TV_IP>"
    exit 1
fi

echo "[*] Stopping unlock listener and connecting to Jio STB at $STB_IP:5555..."
pkill -f python 2>/dev/null || true
adb connect "$STB_IP:5555"

echo ""
echo "=================================================================="
echo "👉 LOOK AT YOUR TV SCREEN!"
echo "   Check 'Always allow from this computer' and click OK on the TV,"
echo "   then press ENTER here to continue..."
echo "=================================================================="
read -r _
adb connect "$STB_IP:5555"

echo "[+] 1/6 Locking in ADB, bypassing Setup Wizard / Block Screen & fixing Clock..."
adb shell settings put global adb_enabled 1
adb shell settings put global development_settings_enabled 1
adb shell settings put global device_provisioned 1
adb shell settings put secure user_setup_complete 1
adb shell settings put global package_verifier_enable 0
adb shell settings put global package_verifier_user_consent 0
adb shell settings put global ota_disable_automatic_update 1
adb shell settings put global ntp_server time.google.com
adb shell settings put global auto_time 1
adb shell settings put global auto_time_zone 1
adb shell settings put global captive_portal_mode 0
adb shell settings put global wifi_sleep_policy 2
adb shell settings put global stay_on_while_plugged_in 3
adb shell settings put global window_animation_scale 0.5
adb shell settings put global transition_animation_scale 0.5
adb shell settings put global animator_duration_scale 0.5
adb shell settings put global enable_freeform_support 1
adb shell settings put global force_resizable_activities 1
adb shell settings put global enable_non_resizable_multi_window 1
adb shell settings put global private_dns_mode hostname
adb shell settings put global private_dns_specifier dns.adguard-dns.com
adb shell setprop persist.adb.tcp.port 5555
adb shell setprop debug.hwui.renderer skiagl

echo "[+] 2/6 Disabling TR-069, OTA Updates, Setup Wizard & Stock Jio Launcher..."
adb shell pm disable-user --user 0 com.jio.tr069client 2>/dev/null
adb shell pm disable-user --user 0 com.jio.httpupdate 2>/dev/null
adb shell pm disable-user --user 0 com.jio.usbupdate 2>/dev/null
adb shell pm disable-user --user 0 com.jio.backgroundscheduler 2>/dev/null
adb shell pm disable-user --user 0 com.jio.stbadservice 2>/dev/null
adb shell pm suspend --user 0 com.iwedia.ui.rjio.launcher.reliance 2>/dev/null
adb shell pm disable-user --user 0 com.iwedia.ui.rjio.launcher.reliance 2>/dev/null
adb shell pm uninstall --user 0 com.jiostb.fti 2>/dev/null

echo "[+] 3/6 Uninstalling 28 Jio Bloatware, Telemetry & Ad Apps (Preserving Remote & BT)..."
for pkg in \
  com.jio.store \
  com.jiostb.jiogames \
  com.aksys.jiogamepad \
  com.jio.media.jiobeats \
  com.jio.media.jionewsstb \
  com.jio.jiocloudpc \
  com.jio.jiopay \
  com.jio.jiocall \
  com.jio.media.jiotvplus \
  com.jio.myjiotv \
  com.jio.media.livetv \
  com.jio.stb.catv \
  com.jiotv.sonyliv \
  com.jio.yt \
  com.jio.web \
  com.jio.stb.bot \
  com.jio.stbwidget \
  com.jio.profileutility \
  com.jio.smartmemorymanager \
  com.jio.appoptimizer \
  com.jio.systemstats \
  com.jio.adc.aka \
  com.jio.adc.embedded \
  com.jio.bioscopecontentservice \
  com.jio.stb.remotediagnose \
  com.teamviewer.quicksupport.addon.jio_stb \
  com.jio.screensaver \
  com.jio.myhome.mediasharedmp
do
  echo -n "    Removing $pkg: "
  adb shell pm uninstall --user 0 "$pkg" 2>/dev/null || echo "skipped"
done

echo "[+] 4/6 Installing Shevery (Built-in Shizuku Server)..."
if [ -f "$HOME/sideload-jiostb/shevery-release.apk" ]; then
    adb install -r "$HOME/sideload-jiostb/shevery-release.apk"
    ADB_BIN="adb"
    ADB_TARGET="$STB_IP:5555"
    adb_cmd() { "$ADB_BIN" -s "$ADB_TARGET" "$@" 2>/dev/null; }
    adb_sh() { adb_cmd shell "$@"; }
    if [ -f "$HOME/sideload-jiostb/lib/adb_helpers.sh" ]; then
        . "$HOME/sideload-jiostb/lib/adb_helpers.sh"
        grant_shevery_permissions "com.hamondev.shevery"
    fi
fi

echo "[+] 5/6 Installing Glassio (Apple TV Liquid Glass OS), SmartTube, App Manager & TV Bro..."
cp ./tv "$PREFIX/bin/tv"
chmod +x "$PREFIX/bin/tv"
echo "$STB_IP" > "$HOME/.tv_ip"

tv install https://github.com/mohammadmrh12/glassio
adb shell pm grant com.glasslauncher.tv android.permission.WRITE_SECURE_SETTINGS 2>/dev/null
adb shell cmd package set-home-activity com.glasslauncher.tv/.MainActivity
adb shell am start -n com.glasslauncher.tv/.MainActivity

tv install smarttube
tv install appmanager
tv install tvbro
tv install aurora
tv install files
tv fix

echo "[+] 6/6 Enabling Seamless Auto-Connect Watchdog in Termux..."
grep -q "tv --watchdog" "$HOME/.bashrc" 2>/dev/null || cat << 'EOF' >> "$HOME/.bashrc"
if ! pgrep -f "tv --watchdog" >/dev/null 2>&1; then
    nohup tv --watchdog >/dev/null 2>&1 &
fi
echo "[⚡] Jio TV Seamless Watchdog Active (Type 'start' or 'tv' anytime)"
EOF

echo ""
echo "[★★★] ALL DONE! Switch your TV Wi-Fi back to DHCP (Automatic) and enjoy! [★★★]"
