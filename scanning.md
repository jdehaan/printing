# Scanning

Scanners use:

- eSCL (Apple AirScan) or WSD (Web Services for Devices) for driverless scanning, which are similar in concept to IPP Everywhere for printing.
- DNS-SD to announce their presence and supported features.

## WSD

### Introduction

WSD (Web Services for Devices) is a network protocol developed by Microsoft that allows devices, such as scanners and printers, to communicate seamlessly over a network.
It is designed to simplify the discovery, configuration, and operation of network-connected devices without requiring additional drivers or software.

### Flow of Operations

1. **Device Discovery**: The WSD-enabled device announces its presence on the network using multicast messages. This allows client devices to detect and list available WSD devices automatically.

2. **Service Description**: Once discovered, the device provides a detailed description of its capabilities and supported operations via a standardized XML-based format.

3. **Session Establishment**: The client establishes a communication session with the device to perform specific operations, such as scanning or printing.

4. **Operation Execution**: The client sends requests (e.g., scan commands) to the device, and the device processes these requests and returns the results.

5. **Session Termination**: After completing the operations, the session is closed, freeing up resources on both the client and the device.

WSD is particularly useful in environments where ease of use and minimal configuration are priorities, as it eliminates the need for manual setup or proprietary drivers.

## Checks

```bash
# Test scanner connectivity
scanimage -L
```

## Restoring poor scans (toner stripes)

Printed pages with missing toner often scan as readable text with vertical or horizontal bands. Flatten the bands **before** binarizing. Thresholding the raw PNG bakes the stripes in.

Work on copies. Goal: print-like black-and-white PNG, a few files by hand.

### GIMP

1. Duplicate the layer and convert to grayscale (`Image → Mode → Grayscale`).
2. Flatten uneven toner:
   - Duplicate the gray layer → `Filters → Blur → Gaussian Blur…` (radius about 40–80 px, wider than a band, smaller than a letter) → set that layer to **Divide** → `Layer → New from Visible`.
   - Or `Filters → Enhance → High Pass…` with a large radius, then `Colors → Levels…` to push paper toward white.
   - Persistent regular bands: `Filters → G'MIC-Qt…` (Repair / Details / FFT) **before** threshold.
3. Optional tiny deskew: `Tools → Transform Tools → Rotate`.
4. `Colors → Threshold…` until paper is white and text is black. If stripes appear, undo past Threshold and strengthen step 2; do not raise global contrast.
5. Reconnect broken glyphs: `Filters → Generic → Erode` once, then `Filters → Generic → Dilate` if strokes got too fat.
6. Speckles: `Filters → Enhance → Despeckle`. Stop if thin letters (`e`, `a`, `8`) open up.
7. Flatten, then `Image → Mode → Indexed…` → **1-bit (black and white)** → export PNG.

Check at 100% and 400%. Repeat with `Filters → Repeat Last` / `Re-Show Last` on the remaining pages.

### Alternatives

- **ScanTailor Advanced**: dedicated page tool (illumination flatten, Sauvola/Wolf binarization, despeckle).
- **ImageMagick** (CLI / Docker):

```bash
magick in.png \
  -colorspace Gray -normalize \
  -lat 40x40+10% \
  -morphology Close Diamond \
  -threshold 50% \
  -type Bilevel \
  out.png
```
