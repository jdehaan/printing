# Ubuntu

**100 % clean Snap-only CUPS** on Ubuntu 24.04 is not only possible,  
It is the **official way** and needs **zero .deb files**.

Ubuntu uses snap for cups as an isolated setup to manage printers and the native debian package is to be considered obsolete.

## Symptoms

Common Signs of Mixed CUPS Setup:

1. **PPD parsing errors** - Different CUPS versions handle PPD files differently
2. **Service instability** - Conflicting services competing for resources
3. **Path conflicts** - ppd paths may be accessed by wrong CUPS version
4. **Port conflicts** - Both trying to bind to port 631

## Check

 A conflicting CUPS setup between native and snap packages is a common issue on Ubuntu/Linux systems.
You can check for installed packages and snap this way:

```bash
# Installation check:
dpkg -l "cups*"    # lists native packgage
snap list cups     # list snap packge if installed

# Runtime check: Verify only one CUPS is running
ps aux | grep cups

# Check which CUPS service is running
systemctl status cups
systemctl status snap.cups.cupsd
```

## Native debian packages

### Uninstall CUPS .deb

Do this at your own risk!!

```bash
# Stop everything that might still be running
sudo systemctl stop cups cups-browsed

# Purge every CUPS .deb that ever existed
sudo apt purge -y \
  cups cups-core-drivers cups-daemon cups-client cups-common \
  cups-server-common cups-filters cups-filters-core-drivers \
  cups-browsed cups-ipp-utils cups-ppdc cups-bsd \
  printer-driver-* 2>/dev/null

# Autoremove orphans
sudo apt autoremove -y

# Delete leftover config & cache
sudo rm -rf /etc/cups /var/cache/cups

# Kill the PPD directory (only if you are 100% sure)
sudo rm -rf /usr/share/ppd
```

Run `dpkg -l | grep -i cups` -> zero lines.

Run `ls /etc/cups` -> "No such file or directory".

### Block .debs forever

This step is optional but clean

```bash
sudo tee /etc/apt/preferences.d/no-cups-deb <<EOF
Package: cups*
Pin: release *
Pin-Priority: -10
EOF
```

## Get rid of cups snap

Do this at your own risk!!

```bash
# Remove the Snap (just in case it’s still there)
sudo snap remove --purge cups
```

Run `snap list | grep cups` -> zero lines.

## CUPS as snap

### Installation

```bash
# Install the official OpenPrinting CUPS Snap
sudo snap install cups

# Open the firewall (only if you share printers)
sudo ufw allow 631
```

pure Snap, zero .debs, auto-updated, sandboxed, and 100 % supported.

### Test

```bash
snap info cups          # shows 2.4.12-2 or newer

# Share a printer with Windows/macOS
sudo snap set cups sharing enabled=true

# Update CUPS (auto, but you can force)
sudo snap refresh cups
```
