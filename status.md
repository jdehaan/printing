# System Status and Querying

## 1. Service Status Commands

### Check CUPS Service Status

```bash
# SystemD service status
systemctl status cups
systemctl status cups-browsed  # Auto-discovery service

# Service management
sudo systemctl start cups
sudo systemctl stop cups
sudo systemctl restart cups
sudo systemctl enable cups
```

### Process Information

```bash
# Check if CUPS daemon is running
ps aux | grep cupsd
pgrep cupsd

# Check listening ports
sudo netstat -tlnp | grep :631
sudo ss -tlnp | grep :631
```

## 2. Printer Discovery and Status

### List Available Printers

```bash
# List all configured printers
lpstat -p
lpstat -t  # Detailed status of all printers

# List printer capabilities
lpoptions -p printer-name -l

# Check printer acceptance status
lpstat -a

# Show default printer
lpstat -d
```

### Network Printer Discovery

```bash
# List available IPP printers on network
lpinfo -v

# List available PPD files (legacy)
lpinfo -m

# DNS-SD discovery
avahi-browse -t _ipp._tcp
avahi-browse -t _printer._tcp
```

## 3. Job Queue Management

### View Print Jobs

```bash
# List current jobs
lpstat -o
lpq  # Berkeley command equivalent

# List jobs for specific printer
lpstat -o printer-name

# Detailed job information
lpstat -W active  # Active jobs
lpstat -W completed  # Recently completed jobs
```

### Job Control

```bash
# Cancel specific job
cancel job-id
lprm job-id  # Berkeley equivalent

# Cancel all jobs for user
cancel -u username

# Cancel all jobs for printer
cancel -a printer-name
```

## 4. Configuration Inspection

### View CUPS Configuration

```bash
# Main configuration file
sudo cat /etc/cups/cupsd.conf

# Printer configurations
sudo cat /etc/cups/printers.conf

# MIME type definitions
cat /etc/cups/mime.types
cat /etc/cups/mime.convs
```

### Check File Permissions

```bash
# CUPS directories
ls -la /etc/cups/
ls -la /var/spool/cups/
ls -la /var/log/cups/

# Verify CUPS user/group
id lp
groups lp
```

## 5. Log Analysis

### CUPS Log Files

```bash
# Access log (HTTP/IPP requests)
sudo tail -f /var/log/cups/access_log

# Error log (daemon and filter errors)
sudo tail -f /var/log/cups/error_log

# Page log (print accounting)
sudo tail -f /var/log/cups/page_log

# View recent errors
sudo journalctl -u cups -f
```

### Log Analysis Commands

```bash
# Filter specific printer errors
sudo grep "printer-name" /var/log/cups/error_log

# Check for authentication issues
sudo grep "Unauthorized" /var/log/cups/access_log

# Monitor job processing
sudo grep "Job" /var/log/cups/error_log | tail -20
```

## 6. Debugging and Troubleshooting

### Enable Debug Logging

```bash
# Edit cupsd.conf to increase log level
sudo sed -i 's/LogLevel warn/LogLevel debug/' /etc/cups/cupsd.conf
sudo systemctl restart cups

# Reset to normal logging
sudo sed -i 's/LogLevel debug/LogLevel warn/' /etc/cups/cupsd.conf
sudo systemctl restart cups
```

### Test Printer Connectivity

```bash
# Test IPP connection
ipptool -tv ipp://printer-ip:631/ipp/print get-printer-attributes.test

# Test network connectivity
ping printer-ip
telnet printer-ip 631

# Test USB printer detection
lsusb | grep -i printer
dmesg | grep -i usb | grep -i printer
```

### Driver and Filter Information

```bash
# List available filters
ls -la /usr/lib/cups/filter/
ls -la /usr/libexec/cups/filter/  # Alternative location

# List backends
ls -la /usr/lib/cups/backend/
ls -la /usr/libexec/cups/backend/  # Alternative location

# Test PPD file (legacy printers)
cupstestppd /etc/cups/ppd/printer-name.ppd
```

## 7. Performance Monitoring

### System Resource Usage

```bash
# CUPS memory usage
ps aux | grep cupsd | awk '{print $6}'

# Disk space usage
df -h /var/spool/cups/
df -h /var/log/cups/

# Job statistics
lpstat -W completed | wc -l  # Count completed jobs
du -sh /var/spool/cups/*     # Spool directory size
```

### Network Performance

```bash
# Monitor network printer traffic
sudo tcpdump -i any port 631

# Check IPP response times
time ipptool ipp://printer-ip:631/ipp/print get-printer-attributes.test
```

## 8. Maintenance Commands

### Clean Up Jobs and Logs

```bash
# Clear completed jobs
sudo cancel -a -x  # Cancel and remove all jobs

# Rotate logs manually
sudo logrotate /etc/logrotate.d/cups

# Clean temporary files
sudo rm -f /var/cache/cups/*
sudo rm -f /tmp/cups-*
```

### Reset Printer Configuration

```bash
# Remove specific printer
sudo lpadmin -x printer-name

# Reset CUPS to defaults
sudo systemctl stop cups
sudo rm -f /etc/cups/printers.conf
sudo rm -f /etc/cups/classes.conf
sudo systemctl start cups
```

