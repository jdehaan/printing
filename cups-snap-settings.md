# CUPS snap queue settings for the Canon MX925

> **Warning: reboot persistence on this Ubuntu system.** Defaults set using
> `snap run cups.lpadmin` or `snap run cups.lpoptions` did not remain effective
> after reboot in the reported setup. Setting them in Ubuntu's printer settings
> worked instead. Start with **Settings > Printers > Canon_MX925** and open
> its printer properties/options (labels vary by Ubuntu version). Set paper
> size to **A4**, media type to **Plain paper / Stationery**, and paper source
> to **Bottom**, then apply the changes. Reopen Okular and verify after reboot.
> Prefer regular A4, not A4 Borderless, for ordinary documents.

This document explains why the Canon MX925 feeds paper from the top (rear)
tray even when **Auto** or **Bottom** is selected, and how to configure the
driverless CUPS snap queue so that plain A4 jobs use the bottom cassette.
General printer and connectivity notes are in [printer.md](printer.md); snap
packaging and filter details are in [cups-snap.md](cups-snap.md).

## Setup

| Item | Value |
|---|---|
| Printer | Canon MX925, reports itself as `Canon MX920 series`, firmware 3.041 |
| Queue | `Canon_MX925`, created by cups-browsed (`implicitclass://Canon_MX925/`) |
| Driver | Driverless IPP Everywhere / AirPrint, `image/urf` at 600 dpi |
| Paper sources | `auto`, `top` (rear tray), `bottom` (front cassette) |

## Symptom

Regardless of the selected media source (`Auto`, `Bottom`, or `Top`), the
printer picks paper from the top tray. The defaults shown in application print
dialogs (for example Okular) do not match the paper actually loaded.

## Problems

### 1. The printer advertises photo defaults

The queue is generated from the attributes the printer reports over IPP:

```text
media-default          = na_index-4x6_4x6in
media-col-default      = {media-size=4x6in media-source=auto media-type=photographic ...}
media-source-supported = auto,top,bottom
media-type-supported   = stationery,photographic,...
```

The driverless queue copies these as its defaults, so applications see:

```text
PageSize/Media Size: ... *4x6 ...
InputSlot/Media Source: Auto Top *Bottom
MediaType/Media Type: Stationery *Photographic ...
```

A4 and plain paper (`Stationery`) are available, but they are not the
defaults. This is why the settings shown in applications do not match the
paper in the cassette.

### 2. Applications send a 4x6 based custom page size

In the logged Okular jobs, every job was submitted with the same size,
whatever source was selected:

| Job | InputSlot | Submitted size |
|---|---|---|
| 1, 3 | `Auto` | `media=Custom.95x142mm` |
| 2, 4 | `Bottom` | `media=Custom.95x142mm` |
| 5 | `Top` | `media=Custom.95x142mm` |

Okular took the 4x6 inch (288x432 pt) default page, subtracted the queue
margins, and sent the remaining printable area (269x402 pt, about 95x142 mm)
as a custom size. The job sent to the printer therefore contained:

```text
media-col = {media-size={x-dimension=9489 y-dimension=14181} media-source=bottom ...}
```

### 3. The printer rejects the media request

95x142 mm is not a size the printer supports. For jobs 4 and 5 the log shows
`Validate-Job` answering:

```text
successful-ok-ignored-or-substituted-attributes (Unsupported media-col)
```

The printer ignores or replaces the whole `media-col`, including
`media-source`, and falls back to its own defaults. The `InputSlot` option is
passed through correctly; the requested size makes the printer discard it.

### 4. Tray selection depends on size and media type

The job does not send a `media-type`, so the printer uses its default
`photographic`. The printer does not report the paper loaded in each tray
(no `media-ready`), so **Auto** cannot select a tray by its contents.

According to Canon's specifications for this model, the front cassette takes
only plain paper in A4, A5, B5, or Letter. Photo paper and small sizes such as
4x6 inches go through the rear tray. A job with a small or custom size and
photo media is therefore sent to the top tray, even with `Bottom` selected.

### 5. Option names in older notes do not exist on this queue

Earlier notes suggested `InputSlot=Cassette`. This queue only accepts
`Auto`, `Top`, and `Bottom`. Always check the queue's values with
`lpoptions -l` before setting an option.

## Solutions

### 1. Set A4 plain-paper defaults on the queue

Use Ubuntu's printer settings first, as described in the warning above; this
was the working approach on this system. The following commands are alternatives
for configuring and diagnosing defaults, not a verified reboot-persistent
solution here.

As root, set server-side defaults for all users on the selected CUPS server:

```bash
sudo snap run cups.lpadmin -p Canon_MX925 \
  -o PageSize-default=A4 \
  -o MediaType-default=Stationery \
  -o InputSlot-default=Bottom
```

Without root, set defaults for the calling user's CUPS client. Applications
using that client's defaults can read them, but applications may have their
own saved settings or a different client configuration:

```bash
snap run cups.lpoptions -p Canon_MX925 \
  -o PageSize=A4 -o MediaType=Stationery -o InputSlot=Bottom
```

#### Why the command-line settings may not survive effectively

CUPS snap does not inherently discard printer settings on reboot. Several
layers can make a saved setting cease to be effective:

- **Automatically managed queue:** `Canon_MX925` uses `implicitclass://` and
  is created/updated by cups-browsed when the printer is rediscovered. This
  regenerates its driverless PPD from printer capabilities. The live log shows
  queue updates and says it restores defaults from the previous cups-browsed
  session. That establishes a separate defaults-restoration path, but does not
  prove it lost or overwrote the command-line changes.
- **Server versus user defaults:** `lpadmin` changes server-side queue defaults;
  `lpoptions` without root saves client defaults for its calling user. Snap
  confinement and client configuration can affect which files and server are
  used. Ubuntu's printer settings and an application's CUPS client must target
  the same queue/server for their defaults to agree.
- **Application overrides:** Okular's saved print settings and per-job options
  can override queue defaults even when those defaults persisted correctly.

Ubuntu's printer settings provide the working configuration path in this
setup, but they still configure printing defaults rather than the printer's
firmware. The precise reason they worked while the commands did not requires
comparing the server, queue and defaults before and after reboot; it is not
established by the symptom alone. Do not add a startup script to reapply the
commands without first identifying which layer is replacing or overriding them.

After applying the Ubuntu settings and again after reboot, inspect:

```bash
snap run cups.lpstat -v
snap run cups.lpoptions -p Canon_MX925
snap run cups.lpoptions -p Canon_MX925 -l
```

In the option list, `*` marks the selected default. Expect `*A4`,
`*Stationery`, and `*Bottom`. Also check Okular's dialog and the submitted job
as described under Verification; a correct option list alone does not prove
that the application used those defaults.

### 2. Select A4 in the application

In Okular's print dialog, set the paper size to **A4** both in the printer
properties and in the page setup. Make sure neither still shows 4x6. Firefox
and other applications keep their own page size settings, so check those too.

### 3. The printer's advertised defaults cannot be changed

The MX92x has no setting for the defaults it advertises over IPP. They are
fixed in the firmware:

- **Web interface** (`http://$PRINTER_IP/`): only has *LAN settings*,
  *Other settings* (printer name, WSD, Bonjour, LPR, PictBridge, DRX,
  location), and *Password settings*. There are no paper settings.
- **IPP**: `operations-supported` lists only `Print-Job`, `Validate-Job`,
  `Create-Job`, `Send-Document`, `Cancel-Job`, `Get-Job-Attributes`,
  `Get-Jobs`, and `Get-Printer-Attributes`. Without `Set-Printer-Attributes`,
  clients cannot change `media-col-default`. The advertised
  `printer-more-info` page (`:631/mainmenu.html`) returns 404.
- **Control panel** (*Menu > Setup > Device settings*): according to
  [Canon's MX920 manual](https://ij.manual.canon/ij/webmanual/Manual/W/MX920%20series/EN/UG/UG_Changing_Settings0100.html),
  *Print settings* only covers paper abrasion, extended copy amount, disc
  print area, and auto photo fix. The only page size and media type defaults
  are under *Mobile phone print settings*, which apply to Bluetooth printing
  with the optional Bluetooth unit, not to IPP.

A firmware update (*Setup > Device settings > Firmware update*) is the only
printer-side change that might affect these values; firmware 3.041 still
advertises 4x6 photo paper. The CUPS queue defaults from solution 1 are the
effective fix.

### 4. Use the rear tray only for photo or small media

Use `InputSlot=Top` together with a photo `MediaType` and a supported photo
size such as `4x6` when printing photos.

## Finding the printer address

The printer announces itself over mDNS (Bonjour) with a host name derived from
its MAC address. List the IPP printers on the network:

```bash
snap run cups.ippfind --ls
```

This prints a URI such as `ipp://000000XXXXXX.local:631/ipp/print`. Resolve
the host name to an IP address:

```bash
getent hosts 000000XXXXXX.local
```

Alternatives:

- On the printer: *Menu > Setup > Device settings > LAN settings >
  Confirm LAN settings* shows the IP address. *Print LAN details* in the same
  menu prints it.
- On the router: look up the printer's MAC address in the DHCP client list,
  and reserve the address there as recommended in [printer.md](printer.md).
- `avahi-browse -rt _ipp._tcp` (package `avahi-utils`) shows the host name
  and address together.

Use the address for `PRINTER_IP` in [printer.md](printer.md), for the web
interface at `http://$PRINTER_IP/`, or as `ipp://$PRINTER_IP:631/ipp/print`
with `ipptool`.

## Verification

List the queue's options and defaults:

```bash
snap run cups.lpoptions -p Canon_MX925 -l
```

Query the printer's advertised defaults directly. Snap confinement hides
`/tmp`, so keep the test file in the home directory:

```bash
PRINTER_URI='ipp://your-printer-host.local:631/ipp/print'
cat > ~/ga.test <<'EOF'
{
OPERATION Get-Printer-Attributes
GROUP operation-attributes-tag
ATTR charset attributes-charset utf-8
ATTR naturalLanguage attributes-natural-language en
ATTR uri printer-uri $uri
ATTR keyword requested-attributes media-default,media-col-default,media-source-supported,media-type-supported,media-supported
}
EOF
snap run cups.ipptool -tv "$PRINTER_URI" ~/ga.test
rm ~/ga.test
```

`snap run cups.ippfind --ls` shows the printer URI.

After printing a test page, check the job in the live log
`/var/snap/cups/current/var/log/error_log`:

```bash
grep -E 'media-col collection|Unsupported media-col' \
  /var/snap/cups/current/var/log/error_log | tail
```

A correct A4 job from the cassette shows a `media-col` with
`x-dimension=21000 y-dimension=29700` and `media-source=bottom`, and no
`Unsupported media-col` response.

## Other log messages

`Unable to detect print-quality, using 'normal'!` is logged as an error but
is harmless; the filter falls back to `normal` quality.
