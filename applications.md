# Applications

## evince

Symptoms: "Informationen werden vom Drucker geholt..."

evince installed as apt can get access to the cups socket denied from app armor as the aarmor profiles look to be still sometimes designed for the apt use case not for cups in a snap.

To confirm this look at the syslog or dmesg

```bash
sudo dmesg
```

If you see lines like this when trying to print, you're in this situation:

```log
[29535.765840] audit: type=1400 audit(1764411739.420:2067): apparmor="DENIED" operation="connect" class="file" info="Failed name lookup - disconnected path" error=-13 profile="/usr/bin/evince" name="run/cups/cups.sock" pid=161902 comm="evince" requested_mask="wr" denied_mask="wr" fsuid=1001 ouid=0
```

To make things work again, uninstall evince as apt and reinstall evince as snap.

```bash
sudo apt remove --purge evince
sudo snap install evince
```
