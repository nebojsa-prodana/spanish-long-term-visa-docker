# Spanish Long-Term Visa Application Workaround

## Overview

This repository contains a Docker-based workaround for applying for long-term residency in Spain through the official government website. Unfortunately, the Spanish government's digital signature system is severely outdated and insecure, requiring obsolete browser technology that modern systems no longer support.

## The Problem

The Spanish government's visa application system has not been updated in over a decade and requires:

- **Java Runtime Environment (JRE) 6/7** with browser plugin support
- **Legacy browsers** that support NPAPI plugins (deprecated since 2015)
- **Outdated operating systems** (Windows 2000/XP/Vista/7)
- **Ancient browser versions** that have known security vulnerabilities

![Spanish Government System Requirements](requirements-screenshot.png)

*Screenshot showing the outdated system requirements from the official Spanish government website*

> **Note**: Save the attached requirements screenshot as `requirements-screenshot.png` in this directory to display the image above.

As shown in the official requirements above, the system demands:
- JRE 6 update 17 or higher (released in 2009!)
- Internet Explorer 7+ or very old versions of Firefox/Chrome
- Support for Java applets in browsers (deprecated technology)

Modern browsers have completely removed support for Java plugins due to security concerns, making it impossible to complete the digital signature process required for visa applications.

## The Solution

This Docker container provides a legacy environment with:

- **Ubuntu 20.04** base system (AMD64 architecture for legacy compatibility)
- **OpenJDK 8** with browser plugin support (compatible with Java 7 applets)
- **Firefox ESR 52** (the last version to support NPAPI plugins)
- **AutoFirma 1.9** (Spanish government's digital signature tool)
- **VNC access** through web browser for remote GUI interaction

## System Requirements

- Docker
- Web browser (for VNC access)
- Your digital certificate files (.p12 or .pfx format)

**Note for Apple Silicon (M1/M2/M3) Macs**: This container uses AMD64 architecture (`--platform=linux/amd64`) because Java 7 and legacy browser plugins were never built for ARM64. Docker will automatically use Rosetta translation on Apple Silicon Macs.

## Quick Start

1. **Clone this repository:**
   ```bash
   git clone <this-repo-url>
   cd long-term-visa
   ```

2. **Place your digital certificates:**
   ```bash
   mkdir certs
   # Copy your .p12 or .pfx certificate files to the certs/ directory
   cp /path/to/your-certificate.p12 certs/
   ```

3. **Build and run the container:**
   ```bash
   make build
   make run
   ```

4. **Access the GUI:**
   - Open your web browser
   - Go to: `http://localhost:8080/vnc.html`
   - Click "Connect" (no password required)

5. **Use Firefox for visa application:**
   - Firefox will open automatically with the Spanish government website
   - Your certificates will be available in Firefox Certificate Manager
   - Proceed with your visa application

## Usage Commands

Once the container is running, you can open a shell for troubleshooting:

```bash
docker exec -it autofirma-legacy bash
```

### Available Commands in Container

Type `visa-help` for a complete list of available commands:

**Website Access:**
- `firefox-spanish` - Open Spanish visa website
- `vnc-web` - Show VNC web access URL

**Certificate Management:**
- `cert-list` - List all certificates in Firefox
- `cert-verify` - Show personal certificates only
- `cert-import-help` - Show how to import certificates
- `cert-debug` - Debug certificate database issues

**System Diagnostics:**
- `java-test` - Test Java installation
- `firefox-test` - Test Firefox installation
- `autofirma-test` - Test AutoFirma installation
- `display-test` - Test X11 display
- `smoke-test` - Run complete system validation

### Certificate Import Process

The container automatically imports certificates from the `certs/` directory using **legacy NSS database format (cert8.db)** for Firefox ESR 52 compatibility.

**Supported formats:** `.p12`, `.pfx`

**Import process:**
1. Place certificate files in the `certs/` directory
2. Start/restart the container
3. Certificates are automatically imported into Firefox
4. Verify import with: `cert-list`

**Manual certificate import:**
```bash
# Inside the container
cert-import-manual /certs/your-certificate.p12
```

## Troubleshooting

### Certificate Not Visible in Firefox
- Check certificate import: `cert-debug`
- Verify database format: Firefox ESR 52 uses legacy cert8.db format
- Manual import: `cert-import-manual /certs/your-cert.p12`

### Firefox Cannot Access Certificates
- Ensure you're using the legacy database format (handled automatically)
- Check Firefox profile: `firefox-profile`
- Restart Firefox: `pkill firefox && firefox-spanish`

### VNC Connection Issues
- Ensure port 8080 is available: `lsof -i :8080`
- Check VNC services: `display-test`
- Restart container if needed: `docker restart autofirma-legacy`

### Java/AutoFirma Problems
- Test Java: `java-test`
- Test AutoFirma: `autofirma-test`
- Check system info: `system-info`

## Technical Details

### Architecture Notes
- **Platform**: AMD64 architecture for legacy Java compatibility
- **Base**: Ubuntu 20.04 LTS
- **Java**: OpenJDK 11 (compatible with Java 7 applets)
- **Browser**: Firefox ESR 52.9.0 (last NPAPI-compatible version)
- **Certificate Database**: Legacy NSS format (cert8.db) for Firefox ESR 52
- **Desktop**: Minimal Openbox window manager
- **Remote Access**: VNC + noVNC for web-based GUI
- **Environment**: Single troubleshooting script sourced in .bashrc handles all setup

### Certificate Database Format

The container uses **legacy NSS database format (cert8.db)** instead of the modern format (cert9.db) because Firefox ESR 52 prefers the legacy format for certificate visibility. This ensures your digital certificates appear correctly in Firefox Certificate Manager.

### Security Considerations

⚠️ **WARNING**: This container deliberately uses outdated, vulnerable software to work around Spanish government incompetence. Use only for visa applications and in isolated environments.

- Firefox ESR 52 has known security vulnerabilities
- Java browser plugins are deprecated for security reasons
- The container should not be used for general browsing
- Only use on trusted networks
- Consider using a dedicated VM for additional isolation

## File Structure

```
├── Dockerfile            # Container with legacy software stack
├── Makefile              # Build and run automation with retry logic
├── start.sh              # Simplified container initialization script
├── troubleshoot.sh       # Troubleshooting tools and commands
├── smoketest.sh          # System validation and health checks
├── configure-firefox.sh  # Firefox configuration (disable updates, dialogs)
├── README.md             # This documentation
└── certs/                # Directory for your .p12/.pfx certificate files
```

## Why This Exists

This workaround exists because:

1. **Government Negligence**: Spanish authorities have failed to update their systems for over 15 years
2. **Technical Debt**: The system was built with obsolete technology and never modernized  
3. **User Impact**: Citizens are forced to use insecure software to access government services
4. **Digital Divide**: Modern computers cannot access basic government services

This is a clear failure of digital governance and puts citizens at risk by forcing them to use vulnerable software.

## License

This project is provided as-is for educational and necessity purposes. The authors are not responsible for any issues arising from the use of deliberately outdated software components.

## Contributing

If you discover improvements or fixes, please contribute back to help other victims of Spanish bureaucratic incompetence.

---

*"The best time to modernize government IT was 20 years ago. The second best time is now."*