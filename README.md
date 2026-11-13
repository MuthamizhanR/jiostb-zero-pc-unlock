# 📺 JioSTB Zero-PC & Zero-Router Unlock (Termux + Hotspot Edition)

[![Platform](https://img.shields.io/badge/Device-JioSTB%20JMSD200%20%2F%20JMSD200A-blue?style=flat-square)](#)
[![Requirement](https://img.shields.io/badge/Requirement-Termux%20%2B%20Mobile%20Hotspot-success?style=flat-square)](#)
[![PC Required](https://img.shields.io/badge/PC%20%2F%20Router-Not%20Required-brightgreen?style=flat-square)](#)
[![Root Required](https://img.shields.io/badge/Root-Not%20Required-brightgreen?style=flat-square)](#)

Unlock **Wireless ADB**, bypass the **"Set-Top Box Blocked"** / Setup Wizard screen, remove all 28 Jio bloatware apps, and convert the **Jio Set-Top Box (`JMSD200` / `JMSD200A`)** into a full Apple TV-style Android TV—**using ONLY an unrooted Android tablet/phone, a mobile hotspot, and pure stubbornness!**

* ❌ **No PC or Laptop**
* ❌ **No Wi-Fi Router or Broadband**
* ❌ **No Ethernet Cable or USB-C Dongles**
* ❌ **No Root** on phone or tablet
* ❌ **No Docker, MongoDB, or GenieACS**

---

## 🔥 The Story Behind This Project (Resource Constraints & What Kept Us Going)

This project was born out of strict resource constraints and a refusal to accept that working hardware is "e-waste."

### 1. The Constraints
We picked up a dirt-cheap **Jio Set-Top Box (`JMSD200`)** as a hobby project to convert it into a clean Android TV box. Every existing guide on GitHub and Reddit (`Housekeeping-PoC`, `sideload-jiostb`, `STB-Comprehensive-Guide`) required:
* A **Windows/Linux PC** capable of running **Docker, MongoDB, GenieACS, and Technitium DNS**
* A **Home Wi-Fi Router** or **Direct Ethernet LAN setup**

**What we actually had:**
* **Zero PC / No Laptop**
* **Zero Wi-Fi Router** (only mobile data)
* **Zero Rooted Devices**
* Just an **unrooted Android tablet** (running Termux) and an **unrooted Android phone** acting as a mobile hotspot.

At first, conventional wisdom and existing documentation said it was **physically impossible**:
* Unrooted Android kernels block apps from binding to **Port 53 (DNS)** and **Port 67 (DHCP)**.
* Unrooted Android devices cannot run **Docker** or **MongoDB** (which crashes inside PRoot).
* Android hotspots use a locked internal `dnsmasq` server that cannot be edited without root.

### 2. The Rock-Bottom Moment ("This Hardware is Useless")
Midway through testing, the STB connected to the mobile hotspot for a few seconds before Static DNS was locked in. It phoned home to Jio's servers, rebooted itself mid-process, and locked itself on the dreaded **"Set-Top Box Blocked"** screen.

A hard pinhole reset made it even worse: the box was now trapped inside the **First-Time Setup Wizard** AND blocked at the same time. Customer support declared that deactivated hardware cannot be recovered and is essentially useless e-waste unless you buy a brand-new connection.

**That was what kept us going.** When you're told that a perfectly capable quad-core Android TV box you own is "useless trash," you don't throw it away—you stay up late and engineer a way around every single lock using the tools in your hands.

---

## ⚔️ Every "Impossible" Roadblock We Crushed

| Roadblock | Why It Happened | How We Bypassed It Without a PC or Root |
| :--- | :--- | :--- |
| **1. No Port 53 (DNS) on Unrooted Android** | Linux/Android forbids non-root apps from listening on privileged ports `< 1024`. | **Outsourced Port 53 to the Cloud:** Used a free **NextDNS** profile over an IPv4 mobile hotspot with a **DNS Rewrite** pointing `jio.com` and `acs.oss.jio.com` back to the tablet's local hotspot IP (`192.168.43.x` / `10.x.x.x`)! |
| **2. No Docker / MongoDB / GenieACS on Tablet** | GenieACS + MongoDB require Docker or x86/systemd, which fail in unrooted Termux. | **Wrote a 90-Line Python CWMP Server (`unlock.py`):** Replaced the entire multi-container GenieACS + MongoDB stack with a single lightweight Python HTTP/SOAP responder inside Termux on `127.0.0.1:7547`. |
| **3. Box Getting Blocked Mid-Setup** | Connecting to the hotspot with Mobile Data ON lets the STB hit Jio's entitlement server and lock itself. | **The Offline Hotspot Trick + Wildcard Rewrite:** Configured the TV's Static IP while **Mobile Data was OFF** (Hotspot ON). Then moved `jio.com` from NextDNS's *Denylist* (which returns `0.0.0.0` and broke `acs.oss.jio.com`) into **NextDNS Rewrites** (`jio.com` → Tablet IP), which redirects all `*.jio.com` subdomains to Termux while simultaneously blackholing Jio's real block servers! |
| **4. Hidden Hotspot Gateway IP (`Permission denied`)** | Android 11+ randomizes hotspot gateway IPs and SELinux blocks `ip route` in Termux. | **The `TTL=1` Ping Trick:** Ran `ping -c 1 -t 1 8.8.8.8` in Termux, forcing the first hop (the phone hotspot gateway) to drop the packet and reveal its exact IP in the `Time to live exceeded` reply! |
| **5. `CWMP Fault 9005` & `Fault 9007` + `Connection Refused` on Port 5555** | 1) Parameter prefix on JMSD200 is `Device.JioSTB.` (not `Device.JSTB.`).<br>2) Newer firmware rejects `DebugValidityDate = 2037...` with `9007`. Because TR-069 `SetParameterValues` is atomic, bundling the date poisoned the batch!<br>3) `JioTR069Client` only starts `adbd` (`:5555`) after a fault-free session closes cleanly with `204 No Content`. | **Atomic Single-Parameter Session:** Modified `unlock.py` to send `Device.JioSTB.USB.USBDebugging = true` **alone** in its own RPC and immediately close the session with `204 No Content`. Port `5555` opened instantly—and we immediately disabled `com.jio.tr069client` over ADB so the validity timer could never expire! |

---

## 📁 Repository Structure

```text
jiostb-zero-pc-unlock/
├── README.md          # Complete step-by-step guide, story & architecture overview
├── setup_termux.sh    # Installs Termux dependencies, global `tv`/`start` CLI, and starts CWMP + TLS proxy
├── unlock.py          # Standalone TR-069 CWMP responder (port 7547) for atomic USBDebugging unlock
├── post_unlock.sh     # 1-click Setup Wizard bypass, OTA/TR-069 disabler, 28-app debloater & launcher installer
└── tv                 # All-in-one Termux Smart Controller with auto-IP discovery, APK resolver & watchdog
```

---

## 🛠️ Step-by-Step Unlock Guide

### Step 1: Prepare Your Hotspot Phone
1. Go to **Settings → Mobile Network → SIM → Access Point Names (APN)** → edit your active APN and change **APN Protocol** and **APN Roaming Protocol** to **IPv4** (prevents IPv6 from bypassing NextDNS).
2. Turn **Personal Hotspot ON**.
3. Turn **Mobile Data OFF** for now!
   *(Keeping Mobile Data OFF while configuring the TV makes it impossible for Jio's servers to block or restart your box while you type).*

---

### Step 2: Set Up Termux (On Your Tablet or 2nd Phone)
1. Install **Termux** from [F-Droid](https://f-droid.org/en/packages/com.termux/) (do not use the outdated Play Store version) and connect to your Hotspot.
2. Temporarily turn Mobile Data ON just to run the installer in Termux:
   ```bash
   pkg update -y && pkg install -y python git android-tools
   git clone https://github.com/MuthamizhanR/jiostb-zero-pc-unlock.git ~/jiostb-zero-pc-unlock
   cd ~/jiostb-zero-pc-unlock
   chmod +x setup_termux.sh post_unlock.sh tv
   ./setup_termux.sh
   ```
3. Note down the **`LAN IPs to put in STB DNS record`** printed by `pass_front.py` — this is your **`TABLET_IP`** (e.g. `192.168.43.50`).
4. Swipe from the left edge of Termux → tap **New session** (Session 2) and find your exact Hotspot **`GATEWAY_IP`**:
   ```bash
   ping -c 1 -t 1 8.8.8.8
   ```
   *(The IP shown right after `From ...` is your `GATEWAY_IP`).*

---

### Step 3: Set Static IP on the Jio STB (With Mobile Data OFF)
1. Turn **Mobile Data OFF** on your Hotspot phone (leave **Hotspot ON**).
2. Plug any USB pendrive into the Jio STB → open **My Music** (or **JioPhotos**) → **Settings → Eject USB → Internal Storage → Apps → Settings → Open**.
3. Go to **Network & Internet → Wi-Fi** → connect to your Hotspot.
4. Click your connected Hotspot → note the TV's **IPv4 Address (`TV_IP`)** → scroll down to **IP settings → Static**:
   * **IP address:** `TV_IP` (e.g. `192.168.43.100`)
   * **Gateway:** `GATEWAY_IP` (from `ping -c 1 -t 1 8.8.8.8` in Step 2)
   * **Network prefix length:** `24`
   * **DNS 1 & DNS 2:** Your two NextDNS IPv4 addresses (`45.90.28.x` & `45.90.30.x` from `my.nextdns.io`)

---

### Step 4: Activate NextDNS Rewrites & Trigger the Unlock
1. Turn **Mobile Data ON** on your Hotspot phone and open [my.nextdns.io](https://my.nextdns.io):
   * Go to **Settings → Rewrites** and add these 4 domains pointing to your **`TABLET_IP`**:
     * `jio.com` → `TABLET_IP`
     * `acs.oss.jio.com` → `TABLET_IP`
     * `acs.oss.j.com` → `TABLET_IP`
     * `acs.jiostb.com` → `TABLET_IP`
   * ⚠️ **Important:** Do **NOT** put `jio.com` in the NextDNS **Denylist**! In NextDNS, Denylist overrides Rewrites and returns `0.0.0.0`. Putting `jio.com` inside **Rewrites** redirects all `*.jio.com` subdomains to your tablet while still blocking Jio's real servers!
   * Go to **Setup → Linked IP** and tap **Link my IP** so the **green dot** turns on.
2. On your TV, toggle **Wi-Fi OFF** for 5 seconds and **Wi-Fi ON** (or unplug the Jio STB power cord for 5 seconds and plug it back in).
3. Watch Termux Session 1—within 15–30 seconds you will see:
   ```text
   [★★★] CLEAN SESSION COMPLETE: USBDebugging = true APPLIED & CLOSED WITH 204! [★★★]
   ```

---

### Step 5: Run the 1-Click Post-Unlock, Debloat & OS Upgrade Script
In Termux Session 2, run:
```bash
cd ~/jiostb-zero-pc-unlock
./post_unlock.sh <YOUR_TV_IP>
```
Accept the **"Allow USB debugging?"** prompt on your TV screen (check *Always allow*). The script will automatically:
* Bypass the Setup Wizard & "Set-Top Box Blocked" screen (`device_provisioned = 1`)
* Disable `com.jio.tr069client` and all Jio OTA services so ADB never expires
* Fix the NTP clock server (`time.google.com`), enable 0.5x animations, Freeform Multi-Window, and AdGuard Private DNS
* Remove 28 Jio bloatware, ad, and telemetry packages while keeping the Jio Remote, Bluetooth, IR volume, and Voice Assistant intact
* Install **Shevery (Shizuku)**, **Glassio (Apple TV Liquid Glass OS)**, **SmartTube**, and the **`tv`** Smart Controller!

Once complete, switch your TV's Wi-Fi back from **Static** to **DHCP (Automatic)** and remove the NextDNS Rewrites!

---

## ⚡ Using the `tv` Smart Controller in Termux

Type **`start`** or **`tv`** anytime in Termux. It automatically scans your hotspot to find the Jio Box (even if the IP changed) and keeps a background watchdog running:

| Command | Description |
| :--- | :--- |
| `start` or `tv` | Auto-finds the Jio Box on your hotspot, connects ADB, and wakes the connection |
| `tv dl` | Grabs the newest `.apk` from your tablet's Chrome `Downloads` folder, installs it onto the TV, and unlocks all permissions |
| `tv install <name/url>` | Auto-downloads the `armeabi-v7a` Android TV version of any preset (`glassio`, `smarttube`, `bitchord`, `aptoidetv`, `nova`, `vlc`, `kodi`, `localsend`, `appmanager`) or any GitHub / F-Droid URL |
| `tv fix` | Force-grants Storage, Install Unknown Apps, Overlay, PiP, and Shevery (Shizuku) permissions to all user apps |
| `tv type "text"` | Types text directly into any search or password box on your TV |
| `tv url "https://..."` | Opens any web URL directly on your TV |
| `tv remove <keyword>` | Uninstalls any TV package matching `<keyword>` |
| `tv reboot` | Reboots the TV box |

---

## 🙏 Credits & Acknowledgements
* **JFC-Group (`Housekeeping-PoC`)** — Original TR-069 vulnerability research
* **Vishal Beniwal (`ilikechocopies/sideload-jiostb`)** — `pass_front.py`, `acs_chain.pem`, and `Shevery`
* **Mohammad (`mohammadmrh12/glassio`)** — Glassio Apple TV Liquid Glass Launcher
