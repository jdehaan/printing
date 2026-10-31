# CUPS Snap

Snap-specific troubleshooting and dependency provenance. Printer hardware
and network connectivity notes are in [printer.md](printer.md); queue defaults
and paper-tray selection are in [cups-snap-settings.md](cups-snap-settings.md).
No apt CUPS installation is required for the procedures below.

## Source and build integration

The packaging source is [OpenPrinting/cups-snap](https://github.com/OpenPrinting/cups-snap).
Its build recipe is the root-level
[snapcraft.yaml](https://github.com/OpenPrinting/cups-snap/blob/master/snapcraft.yaml),
not a file under a `snap/` directory.

The printing components are fetched as separate **Snapcraft parts**, not Git
submodules. Each part declares an upstream Git `source`, a `source-tag`, and
`source-depth: 1`. Snapcraft checks out that tag, builds it with the `autotools`
plugin, and stages the resulting files into the snap. `after` declares the build
order; it is not a version constraint. Build environments refer to `CRAFT_STAGE`
to find the libraries produced by earlier parts.

The recipe inspected on 2026-10-31 selected:

| Part | Source repository | Selected tag | Role |
| ---- | ----------------- | ------------ | ---- |
| cups | [OpenPrinting/cups](https://github.com/OpenPrinting/cups) | v2.4.20 | Scheduler and command-line tools |
| pdfio | [michaelrsweet/pdfio](https://github.com/michaelrsweet/pdfio) | v1.6.6 | PDF parser used by the newer page-count helper |
| ghostscript | [ArtifexSoftware/ghostpdl](https://github.com/ArtifexSoftware/ghostpdl) | ghostpdl-10.08.0 | Rendering engine |
| libcupsfilters | [OpenPrinting/libcupsfilters](https://github.com/OpenPrinting/libcupsfilters) | 2.2.1 | Filter logic, including the defective page-count helper |
| libppd | [OpenPrinting/libppd](https://github.com/OpenPrinting/libppd) | 2.1.1 | PPD support and filter wrappers |
| cups-filters | [OpenPrinting/cups-filters](https://github.com/OpenPrinting/cups-filters) | 2.0.1 | Executable CUPS filters |
| cups-browsed | [OpenPrinting/cups-browsed](https://github.com/OpenPrinting/cups-browsed) | 2.1.1 | Discovery and automatic queues |

The relevant build order is:

```text
cups + pdfio + ghostscript -> libcupsfilters
cups + ghostscript + libcupsfilters -> libppd
cups + ghostscript + libcupsfilters + libppd -> cups-filters
```

`build-packages` supplies development tools and headers in the build environment.
`stage-packages` brings selected distribution packages into the staged snap.
Neither list alone describes the source-built libcupsfilters revision. The snap
bundles its filter libraries; changing the host's apt libraries will not patch
them.

Recipe hooks can modify upstream source after checkout. For example, the
inspected recipe applies a GCC 15 build patch to cups-filters and adjusts a
libppd tool path. Check `override-pull`, `override-build`, and referenced patches,
not only `source-tag`. The inspected libcupsfilters part has no such patch hook.

This describes the recipe inspected on that date, not proven source provenance
for every published snap revision. A current Git branch can differ from the
recipe used to build an older artifact.

## PDF page-count bug

Investigation date: **2026-10-31**.

Failed print jobs reported `cfFilterGhostscript: Unexpected page count`.
The preceding messages were `Unable to find start of cross-reference table` and
`Missing Root object`. CUPS stopped the queue after the filter failure.

The defect is in libcupsfilters' `cfPDFPagesFP()`, called by the Ghostscript
filter before rendering. It copies the PDF into a temporary file through buffered
stdio, then calls `pdfioFileOpen()` without first flushing that output stream.
The parser can therefore see a truncated PDF, missing its cross-reference data
and document root, even though the incoming PDF is sound. The helper returns an
error, which the filter reports as an unexpected page count.

The snap's bundled one-page PDF reproduces the failure with the printer PPD.
Ghostscript reads the original PDF successfully on its own, and `pdftopdf`
produces recognizable PDF output when PDF is the requested final format.
These results, together with inspection of the installed helper, identify a
filter-library defect, not a WiFi, paper-tray, or apt-versus-snap conflict.
The `Last filter could not get determined` message concerns page logging and is
not the fatal page-count error.

### Revision findings (amd64)

Snap revision numbers matter: different revisions can share a version string.

| Revision | Version | Has this bug? | Evidence |
| -------- | ------- | ------------- | -------- |
| 1200 | 2.4.19-1 | No | Downloaded from the store; QPDF-based helper reads the input stream directly and returns 1 page for the bundled test PDF. |
| 1268 | 2.4.20-1 | Yes | Printing and bundled-PDF failures; helper lacks a flush before `pdfioFileOpen()`. |
| 1272 | 2.4.20-1 | Yes | Downloaded from the store; library is byte-identical to revision 1277 and has the defective helper. |
| 1277 | 2.4.20-1 | Yes | Bundled-PDF test fails; helper still lacks the flush. |
| 1279 | 2.4.20-2 | Yes | Downloaded from edge; disassembly shows `pdfioFileOpen()` before flushing or closing the temporary output stream. |

On the investigation date, stable offered 1277 and edge offered 1279; candidate
and beta followed stable. Neither advertised build contains the fix. Switching
to edge is therefore not a remedy for this bug. The checked revisions do not
establish the exact first affected revision or classify every historical build.

### Historical revision without this bug

Revision **1200** is a downloadable amd64 snap using base `core22`. Revisions
1272 and 1279 use `core26`. The older revision avoids this specific bug because
its page-count helper uses QPDF rather than the defective PDFio temporary-file
implementation; it does not contain a backport of the missing-flush fix.

### Expert mode: build and test a fixed snap

This procedure builds the packaging checkout with the libcupsfilters fix pinned
to commit `e7356ce13c96f0e29402d9b03f615eab24c68cc0`. The existing local checkout
already has this `source-commit` in `snapcraft.yaml`; do not clone over it or
replace it with a floating `master` branch. The build log shows Snapcraft using
its managed LXD provider and stopping before compilation because the login did
not have LXD permissions.

**Security:** members of the `lxd` group can effectively obtain root access to
the host. Only grant this to a trusted account, and remove the membership after
building if it is not otherwise needed.

From the account that will build the snap, grant LXD access:

```bash
sudo usermod -aG lxd "$USER"
```

Log out of the desktop and all terminal sessions for that account, then log
back in. A new login session is required for the supplementary group to take
effect. Verify the group before running Snapcraft:

```bash
id -nG
lxc list
```

The first command should include `lxd`; `lxc list` should connect without a
permissions error. If Snapcraft is not installed yet:

```bash
sudo snap install snapcraft --classic
```

Build from the existing packaging checkout. Substitute its path if it is not
under the printing notes directory:

```bash
cd /path/to/printing/cups-snap
git diff -- snapcraft.yaml
snapcraft clean libcupsfilters libppd cups-filters cups-browsed scripts cups-proxyd
snapcraft
ls -lh ./*.snap
```

Check that the diff pins `libcupsfilters` to the intended commit and that
Snapcraft completes successfully. Cleaning these parts removes cached build
outputs for the changed library and downstream parts, so Snapcraft rebuilds them.
The build may take a while and needs network access and disk space. Keep the
resulting amd64 snap filename for the next steps. If desired, remove LXD access
now, then log out and back in again:

```bash
sudo gpasswd -d "$USER" lxd
```

Installing a locally built snap replaces the installed `cups` snap only after
the existing snap is removed, so expect a short printing outage. First save
Snap-managed data and note the snapshot ID:

```bash
sudo snap save cups
snap saved
```

Stop or cancel active print jobs. From the build directory, set `SNAP_FILE` to
the exact artifact produced above, then remove the installed snap and install
the local package. Do not use a wildcard if more than one artifact is present.

```bash
SNAP_FILE='./cups_2.4.20-2_amd64.snap'
sudo snap remove cups
sudo snap install --dangerous "$SNAP_FILE"
snap list cups
```


`--dangerous` permits installation of the locally built, unsigned snap; it does
not disable confinement. Snap normally preserves data on removal. Check that
the printer queues and settings returned; if not, restore the snapshot using
the ID shown by `snap saved` (`sudo snap restore SNAPSHOT_ID cups`).

Before resuming real jobs, rerun the bundled-PDF filter test **without** the
streaming workaround. It must exit successfully and must not report `Missing
Root object` or `Unexpected page count`:

```bash
PRINTER='your-printer-queue'
sudo snap run cups.cupsfilter \
   -p "/var/snap/cups/common/etc/cups/ppd/${PRINTER}.ppd" \
   -m image/urf \
   /snap/cups/current/share/cups/data/default-testpage.pdf \
   > /dev/null
```

Then enable the queue and send a simple test print. If the test fails or the
snap does not start, use the Store return procedure below.

#### Return to the Snap Store channel

First try an in-place refresh to the upstream stable channel. `--amend` allows
Snap to attempt refreshing a locally installed snap that is unknown to the Store:

```bash
sudo snap refresh cups --channel=latest/stable --amend
snap list cups
```

If the refresh succeeds, verify that Tracking reports `latest/stable`, check
that CUPS is running and the printer queues remain available, then remove the
local `.snap` file as described below. If Snap reports that it cannot refresh
the sideloaded package, use the remove-and-reinstall fallback.

Before removing the locally installed build, save its data and note the
snapshot ID:

```bash
sudo snap save cups
snap saved
```

Remove the sideloaded snap, then install the Store release on the stable channel.
This gives the installation stable-channel tracking again.

```bash
sudo snap remove cups
sudo snap install cups --channel=latest/stable
snap list cups
```

Check that `snap list cups` reports `latest/stable` under Tracking. Check that
the printer queues and settings are present; if they are missing, restore the
snapshot using the ID from `snap saved`:

```bash
sudo snap restore SNAPSHOT_ID cups
```

Once the Store snap is running and its data is verified, remove the local
package file if you no longer need it. Replace the example with the exact path
you used for `SNAP_FILE`:

```bash
rm -- ./cups_2.4.20-2_amd64.snap
```

As of the investigation date, stable revision 1277 has the known bug, so this
return restores the upstream package but also restores the original failure.
The local build has not been tested here; treat the filter test and physical
test print as required validation before relying on it.

Downloads were obtained with `snap download cups --revision=REVISION` and
inspected using `unsquashfs` and `objdump`. Each downloaded snap's
`meta/snap.yaml` confirmed its version and amd64 architecture. A controlled test
loaded each helper with its matching snap libraries and called `cfPDFPagesFP()`
on the same bundled `default-testpage.pdf`:

| Helper revision | Result |
| --------------- | ------ |
| 1200 | 1 page, success |
| 1277 | -1, with cross-reference and missing-root errors |

This verifies the page-count behavior, not the entire historical snap service,
printer filter pipeline, or physical printing.

To try the historical revision explicitly (requires administrator approval):

```bash
sudo snap refresh cups --revision=1200
snap list cups
```

Then repeat the offline filter test below **without**
`-o filter-streaming-mode=true`, to check the normal pipeline. Only resume the
queue after this succeeds. Revision 1200 is older software and has not been
audited for other bugs or security fixes, so treat it as a temporary rollback,
not a permanent recommendation. A refresh to stable would reintroduce this bug
as of the investigation date. An optional seven-day refresh hold is
`sudo snap refresh --hold=7d cups`; remove it with
`sudo snap refresh --unhold cups` once a corrected build is available.

### Temporary workaround

The option `filter-streaming-mode=true` bypasses the faulty pre-check. It also
skips PDF preparation such as page selection, scaling, and N-up layout, so use a
PDF already sized for the intended paper. This workaround has not yet been
verified by a successful filter run or physical print in this investigation.

Set `PRINTER` to your queue name. The following offline test does not submit a
print job:

```bash
PRINTER='your-printer-queue'
sudo snap run cups.cupsfilter \
  -p "/var/snap/cups/common/etc/cups/ppd/${PRINTER}.ppd" \
  -m image/urf \
  -o filter-streaming-mode=true \
  /snap/cups/current/share/cups/data/default-testpage.pdf \
  > /dev/null
```

If the test succeeds, apply the option to an individual PDF print job:

```bash
snap run cups.lp -d "$PRINTER" \
  -o filter-streaming-mode=true /absolute/path/document.pdf
```

The queue must be enabled before printing. Cancel or hold the failed job before
resuming the queue so it does not immediately fail again. Do not make streaming
mode a permanent default; the permanent repair is a snap with the corrected
helper.

## Determining whether the fix is included

The fix belongs in
[libcupsfilters cupsfilters/pdf.c](https://github.com/OpenPrinting/libcupsfilters/blob/master/cupsfilters/pdf.c),
not in CUPS, libppd, or PDFio. Upstream adds `fflush(temp_fp)` before
`pdfioFileOpen()`. A newer PDFio dependency alone does not fix a missing flush in
its caller.

Dependency names and displayed versions alone are **not sufficient**. Use the
exact libcupsfilters source revision plus any packaging patches:

1. Obtain the recipe and source manifest or build log for the specific snap
   revision and architecture. Do not substitute today's `master` recipe.
2. Find the libcupsfilters `source-tag`, `source-commit`, or `source-branch` and
   resolve it to the actual commit used by that build.
3. Inspect `cfPDFPagesFP()` at that commit. For the PDFio implementation, the
   output must be flushed or closed successfully before `pdfioFileOpen()`.
4. Check packaging hooks and patches for a backport, a revert, or source changes.
5. Confirm that the resulting library is staged and not replaced by another
   part or distribution package.

A branch name is mutable; a commit hash is stronger evidence. Even a tag should
be resolved to its commit. A fix on upstream `master` does not automatically
enter a snap pinned to a release tag. A corrected build must select a source
revision containing the fix or apply a backport, then rebuild and publish the
snap.

`snap list cups` and `meta/snap.yaml` identify the snap version and runtime
metadata, not necessarily all embedded library source commits. Some builds
include provenance in `snap/manifest.yaml`; check whether it exists and what it
actually records. If exact provenance is missing, dependencies cannot prove
patch inclusion: inspect the artifact and run the focused page-count test.

### Exact upstream commits

| Change | Commit | Date |
| ------ | ------ | ---- |
| Original missing-flush fix | [e14bad406189a66bdeb40131112944bfb58ee0cc](https://github.com/OpenPrinting/libcupsfilters/commit/e14bad406189a66bdeb40131112944bfb58ee0cc) | 2026-08-18 |
| Check temporary-file writes and flush errors | [e7356ce13c96f0e29402d9b03f615eab24c68cc0](https://github.com/OpenPrinting/libcupsfilters/commit/e7356ce13c96f0e29402d9b03f615eab24c68cc0) | 2026-10-19 |

The original fix was merged through
[libcupsfilters PR 167](https://github.com/OpenPrinting/libcupsfilters/pull/167).
The later commit retains the flush and checks both `fwrite()` and `fflush()`
for errors. These changes are in libcupsfilters itself; they do not require a
libppd submodule update or a change to PDFio's implementation.

Tag `2.2.1` resolves to `2a00cf6aa4234e2e0ac91b9844ab8990d04c7089`.
Its [pinned helper source](https://github.com/OpenPrinting/libcupsfilters/blob/2a00cf6aa4234e2e0ac91b9844ab8990d04c7089/cupsfilters/pdf.c)
lacks the flush. It was the latest tag listed by the upstream tags API during
this investigation; no release tag containing the fix was identified.
Do not assume an unverified minimum release version such as `2.2.2`.

### Evidence from the published snap

Revision 1277 includes both its build recipe and a manifest:

```bash
sed -n '/^  libcupsfilters:/,/^  libppd:/p' \
   /snap/cups/current/snap/snapcraft.yaml
sed -n '/^  libcupsfilters:/,/^  libppd:/p' \
   /snap/cups/current/snap/manifest.yaml
```

Run these against the installed revision, or extract the same paths from a
downloaded snap. The 1277 metadata declares libcupsfilters `source-tag: 2.2.1`
with no libcupsfilters patch hook and no resolved source commit. Its PDFio tag
is `v1.6.5`, whereas the current online recipe selects `v1.6.6`. This difference
illustrates why today's packaging repository is not sufficient evidence for an
older published artifact.

For this particular build, the pinned source lacks the fix and binary
inspection plus the page-count test confirms the defect. The presence of
PDFio, the snap's `2.4.20-1` version, and its `core26` base alone would not have
established that result.

### Dependency-only decision rule

| Dependency evidence | Conclusion about this bug |
| ------------------- | ------------------------- |
| QPDF-based `cfPDFPagesFP()` reading the input directly, as verified in revision 1200 | This particular PDFio temporary-file defect is absent; this is avoidance, not a backport. |
| Unmodified libcupsfilters tag `2.2.1` | Affected: the pinned helper lacks the flush. |
| Exact source commit includes the original fix and no subsequent revert | The missing-flush defect is fixed in that source; still check packaging modifications and which library is shipped. |
| Same old tag plus a verified packaging backport of the fix | Can be fixed without changing the dependency's advertised version. |
| Only CUPS version, PDFio version, base snap, or a floating source branch is known | Insufficient evidence. |

In a full libcupsfilters Git checkout, ancestry is a useful first check:

```bash
git fetch origin --tags
FIX='e14bad406189a66bdeb40131112944bfb58ee0cc'
SOURCE_COMMIT='actual-resolved-build-commit'
git merge-base --is-ancestor "$FIX" "$SOURCE_COMMIT"
```

Exit status 0 means the fix is an ancestor; 1 means it is not. A cherry-picked
backport can contain the fix without that ancestry, and a later revert can
remove it while retaining the ancestry. Inspect the resulting helper and patch
list rather than using this test alone. The shallow `source-depth: 1` checkout
used during snap builds may need its history fetched before ancestry checks.

For a corrected packaging build, maintainers can select a release containing
the fix once available, replace `source-tag` with an appropriate fixed
`source-commit`, or apply a backport in `override-pull` after `craftctl default`.
They must rebuild the affected parts without stale cached source, preserve the
existing configure flags and build dependencies, and publish a new snap
revision. Changing only the CUPS version string or the PDFio tag is not enough.

### Artifact fallback

For the installed amd64 library:

```bash
objdump -d --disassemble=cfPDFPagesFP \
  /snap/cups/current/lib/libcupsfilters.so.2.0.0
```

In the audited binaries, the defective helper writes with `fwrite()` and calls
`pdfioFileOpen()` before any `fflush()` or `fclose()` on the output stream.
Finding an arbitrary `fflush` symbol elsewhere in the library is not evidence
that this helper is fixed. Other architectures, library names, or compiler
optimizations may require a different disassembly command.

## Queue tools and paper source

These commands use the utilities bundled in the CUPS snap:

```bash
PRINTER='your-printer-queue'
snap run cups.lpstat -p
snap run cups.lpoptions -p "$PRINTER" -l
```

Use only option names and values listed by the queue. For example, if
`InputSlot` lists `Bottom`, set the per-user default with:

```bash
snap run cups.lpoptions -p "$PRINTER" -o InputSlot=Bottom
```

`Bottom`, `Cassette`, and `MediaSource` are not interchangeable universal
settings. An application can override queue defaults for an individual job.
The MX925 paper-tray analysis is in [cups-snap-settings.md](cups-snap-settings.md).
