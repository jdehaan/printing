# Printing Software Architecture

## Overview

Ubuntu's printing system is built around the Common Unix Printing System (CUPS), which operates as a standards-based, open-source printing system. The architecture is designed around a central scheduler that manages print jobs, printers, and user requests through standardized protocols.

![Architecture Diagram](./svg/architecture_cupsd.svg)

The `cups-browsed` daemon simplifies printer management by automatically discovering and configuring network printers.

**Key Features:**

- Discovers printers via DNS-SD (Bonjour/Avahi)
- Automatically creates and removes print queues
- Supports clustering of printers for load balancing
- Ensures seamless integration with driverless printing
- Provides fallback options for unavailable printers

**Workflow Diagram:**

![cups-browsed Workflow](./svg/architecture_cups-browsed.svg)

## Core Components

### 1. CUPS Scheduler (cupsd)

The heart of the printing system is the CUPS scheduler daemon (`cupsd`), which:

- Acts as an HTTP/1.1 and IPP/2.1 server
- Manages print queues, jobs, and printer status
- Handles authentication and access control
- Provides web-based administration interface
- Coordinates with filters, backends, and other components

**Key Characteristics:**

- Single-threaded server process for reliability
- External helper processes for printing tasks
- Runs as privileged user but spawns jobs as 'lp' user
- Memory and CPU limited primarily by system resources

### 2. Configuration Architecture

**Primary Configuration Files:**

- `/etc/cups/cupsd.conf` - Main server configuration
- `/etc/cups/printers.conf` - Printer definitions and settings
- `/etc/cups/classes.conf` - Printer class configurations
- `/etc/cups/subscriptions.conf` - Event notification subscriptions
- `/etc/cups/mime.types` - File type definitions
- `/etc/cups/mime.convs` - Format conversion rules

**PPD Files (Legacy):**

- Located in `/etc/cups/ppd/`
- PostScript Printer Description files
- Being phased out in favor of driverless printing

### 3. Job Processing Pipeline

**Job Storage:**

- Spool directory: `/var/spool/cups/`
- Control files: `cXXXXX` (IPP job attributes)
- Data files: `dXXXXX-001` (actual print data)
- Automatic cleanup after job completion

**Processing Flow:**

```text
User Application → CUPS Scheduler → Filter Chain → Backend → Printer
```

### 4. Filter System

Filters convert job files into printer-ready formats:

**Standard CUPS Filters:**

- Text filters (text to PostScript)
- PostScript filters (PS optimization)
- PDF filters (PDF to PostScript/raster)
- Image filters (JPEG, PNG, TIFF to raster)
- HP-PCL and ESC/P printer drivers

**Driverless Printing Filters:**

- IPP Everywhere support
- Automatic format negotiation
- Direct PDF/PWG-Raster processing

### 5. Backend System

Backends handle communication with actual printers:

**Standard Backends:**

- `ipp` - IPP network printers
- `http/https` - HTTP-based printing
- `socket` - AppSocket/JetDirect protocol
- `usb` - USB-connected printers
- `lpd` - Legacy Line Printer Daemon
- `snmp` - SNMP-based discovery

**Driverless Backend Features:**

- Automatic printer discovery via DNS-SD/mDNS
- IPP Everywhere capability detection
- Self-configuring printer setup

## Ubuntu-Specific Integration

### 1. Desktop Environment Integration

**GNOME Integration:**

- `gnome-control-center` provides printer settings GUI
- Integration with GNOME system settings panel
- Automatic printer discovery notifications

**Command-line Tools:**

- System V commands: `lp`, `lpstat`, `cancel`, `lpadmin`
- Berkeley commands: `lpr`, `lpq`, `lprm`, `lpc`
- CUPS-specific: `cupsenable`, `cupsdisable`, `cupsaccept`, `cupsreject`

#### 2. Driverless Printing Architecture

**Discovery Process:**

1. Network scanning via DNS-SD (Bonjour/Avahi)
2. IPP service detection on port 631
3. Printer capability query via IPP Get-Printer-Attributes
4. Automatic queue creation with optimal settings

**IPP Everywhere Workflow:**

```text
Application → CUPS → IPP Everywhere Filter → IPP Backend → Network Printer
```

**Supported Formats:**

- PDF (preferred for vector graphics)
- PWG-Raster (for raster images)
- JPEG (direct image printing)
- Apple Raster (macOS compatibility)
