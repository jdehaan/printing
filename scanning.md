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
