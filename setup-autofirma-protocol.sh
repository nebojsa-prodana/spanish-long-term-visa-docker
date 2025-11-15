#!/bin/bash
set -euo pipefail

# Setup AutoFirma protocol handler - critical for Firefox to invoke AutoFirma
# Based on autofirma-docker implementation

# Load common variables
source /usr/local/bin/common-vars.sh

main() {
    echo "Setting up AutoFirma protocol handler..."
    
    # Check if afirma.desktop already exists (it should from the AutoFirma package)
    if [ -f "$AFIRMA_DESKTOP" ]; then
        echo "✓ afirma.desktop already exists from AutoFirma package"
    else
        echo "Creating afirma.desktop file..."
        cat > "$AFIRMA_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=AutoFirma
Comment=Cliente de firma electrónica
Exec=/usr/bin/autofirma %u
Icon=autofirma
StartupNotify=true
NoDisplay=true
MimeType=x-scheme-handler/afirma;
EOF
        echo "✓ afirma.desktop created"
    fi
    
    # Create system-wide MIME type handler for afirma:// URLs
    cat > "${APPLICATIONS_DIR}/mimeapps.list" << 'EOF'
[Default Applications]
x-scheme-handler/afirma=afirma.desktop
EOF

    # Register MIME type handler using xdg-mime
    echo "Registering AutoFirma protocol handler with xdg-mime..."
    xdg-mime default afirma.desktop x-scheme-handler/afirma 2>/dev/null || \
    echo "⚠ xdg-mime registration failed (may need to run as user)"
    
    # Update desktop database
    echo "Updating desktop database..."
    sudo update-desktop-database "$APPLICATIONS_DIR" 2>/dev/null || \
    echo "⚠ Desktop database update failed"

    echo "✓ AutoFirma protocol handler configured"
}

main "$@"