#!/bin/bash
set -euo pipefail

# Setup AutoFirma protocol handler - critical for Firefox to invoke AutoFirma
# Based on autofirma-docker implementation

main() {
    echo "Setting up AutoFirma protocol handler..."
    
    # Check if afirma.desktop already exists (it should from the AutoFirma package)
    if [ -f "/usr/share/applications/afirma.desktop" ]; then
        echo "✓ afirma.desktop already exists from AutoFirma package"
    else
        echo "Creating afirma.desktop file..."
        cat > /usr/share/applications/afirma.desktop << 'EOF'
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
    
    # Create system-wide MIME type handler for afirma:// URLs (use the correct filename)
    cat > /usr/share/applications/mimeapps.list << 'EOF'
[Default Applications]
x-scheme-handler/afirma=afirma.desktop
EOF

    echo "✓ AutoFirma protocol handler configured"
}

main "$@"