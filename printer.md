# WiFi printer

brand: Canon MX925
os: linux
driver: driverless mode

The PC uses wired LAN; the printer uses WiFi and a router-assigned address.

Commands use `$PRINTER_IP` for the printer's network address. Set it to your
own value before running commands:

```bash
PRINTER_IP='your-printer-address'
```

## issues

- sometimes looses connectivity to the WLAN
- printing leads to the printer taking paper from the top loader instead of the bottom, see [cups-snap-settings.md](cups-snap-settings.md)
- same issues with the scanner regarding connectivity

## tried out

- reconfiguring the Wifi connection
- reinstall cups
- reinstall the printer
- configured fixed IP for the printer

## CUPS Snap

Snap-specific filter bugs, tested revisions, workarounds, source repositories,
and dependency verification are documented in [cups-snap.md](cups-snap.md).

## Root Causes and Solutions

### 1. **WiFi Connectivity Issues**

**Root Causes:**

- **Power Management**: The printer's WiFi module may be entering sleep mode to save power
- **WiFi Signal Strength**: Weak signal between printer and router
- **DHCP Lease Expiration**: Even with fixed IP, DHCP lease timeouts can cause disconnections
- **Router WiFi Channel Congestion**: Interference from other devices

**Solutions:**
```bash
# Check WiFi signal strength and interference
sudo iwlist scan

# Monitor network connectivity
ping -c 10 "$PRINTER_IP"
```

**Recommended Fixes:**

- **Disable WiFi Power Saving** on the printer (check printer's network settings menu)
- **Position printer closer** to the router or add a WiFi extender
- **Change router WiFi channel** to less congested one (1, 6, or 11 for 2.4GHz)
- **Set static IP** on both router AND printer to avoid DHCP conflicts
- **Update printer firmware** via Canon's website

### 2. **Paper Tray Selection Issue**

The printer feeds from the top tray whatever the selected source, because the
printer's own defaults are 4x6 inch photo paper. Applications then send a
custom size the printer rejects, and photo or small media can only use the top
tray. The analysis, queue settings, and verification steps are in
[cups-snap-settings.md](cups-snap-settings.md).

### 3. **Scanner Connectivity Issues**

**Root Cause:**

- **SANE Backend**: Scanner drivers may not handle network timeouts gracefully
- **Same WiFi Issues**: Scanner uses same network connection as printer

**Solutions:**

```bash
# Test scanner connectivity
scanimage -L

# Configure SANE for better network handling
echo "$PRINTER_IP" | sudo tee -a /etc/sane.d/pixma.conf

# Set longer timeout in SANE
echo "timeout = 60" | sudo tee -a /etc/sane.d/dll.conf
```

## Comprehensive Fix Strategy

### Immediate Actions

**Router Configuration:**

- Reserve an IP address for the printer's MAC address in the router
- Change WiFi channel if experiencing interference
- Enable WiFi band steering if available

**Printer Settings:**

- Access the printer web interface at its network address
- Disable power saving for WiFi
- Update firmware
- Set default paper source to cassette/bottom tray

**Linux System:**

### Long-term Monitoring

```bash
# Create monitoring script
cat > ~/monitor_printer.sh << 'EOF'
#!/bin/bash
PRINTER_IP='your-printer-address'
while true; do
  if ! ping -c 1 -W 5 "$PRINTER_IP" > /dev/null 2>&1; then
        echo "$(date): Printer offline" >> ~/printer_log.txt
        # Attempt to wake printer
    nc -z "$PRINTER_IP" 9100
    fi
    sleep 300  # Check every 5 minutes
done
EOF
chmod +x ~/monitor_printer.sh
```

The key is addressing the WiFi reliability first (hardware/router settings), then fixing the software-level printing preferences. The driverless mode should work fine once the connectivity is stable and paper source is properly configured.
