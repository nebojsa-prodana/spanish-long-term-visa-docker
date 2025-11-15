#!/bin/bash
set -euo pipefail

# AutoFirma Post-Installation Setup
# Fail fast for faster iteration

# Load common variables
source /usr/local/bin/common-vars.sh

echo "=== AutoFirma Post-Installation Setup ==="

# Step 1: Generate AutoFirma CA and SSL certificates
echo "Generating AutoFirma certificates..."
if [ ! -f "$AUTOFIRMA_CONFIGURATOR" ]; then
    echo "ERROR: autofirmaConfigurador.jar not found at $AUTOFIRMA_CONFIGURATOR!"
    exit 1
fi

cd "$AUTOFIRMA_DIR"
java -Djava.awt.headless=true -jar "$AUTOFIRMA_CONFIGURATOR"
echo "✓ AutoFirma certificates generated"

# Step 2: Execute AutoFirma's certificate installation script if it exists
echo "Running AutoFirma certificate installation script..."
if [ -f "${AUTOFIRMA_DIR}/script.sh" ]; then
    chmod +x "${AUTOFIRMA_DIR}/script.sh"
    "${AUTOFIRMA_DIR}/script.sh"
    rm -f "${AUTOFIRMA_DIR}/script.sh"
    echo "✓ AutoFirma certificate script executed"
else
    echo "INFO: AutoFirma script.sh not found (this may be normal)"
fi

# Step 3: Install AutoFirma CA certificate in system certificate store
echo "Installing AutoFirma CA certificate in system store..."
if [ ! -f "$AUTOFIRMA_ROOT_CER" ]; then
    echo "ERROR: Autofirma_ROOT.cer not found at $AUTOFIRMA_ROOT_CER!"
    exit 1
fi

# Convert DER to PEM format
sudo openssl x509 -inform der -in "$AUTOFIRMA_ROOT_CER" -out "${AUTOFIRMA_DIR}/Autofirma_ROOT.crt"

# Install in system certificate stores
sudo mkdir -p /usr/share/ca-certificates/AutoFirma/
sudo cp "${AUTOFIRMA_DIR}/Autofirma_ROOT.crt" /usr/share/ca-certificates/AutoFirma/AutoFirma_ROOT.crt
sudo cp "${AUTOFIRMA_DIR}/Autofirma_ROOT.crt" "$AUTOFIRMA_ROOT_CRT"

# Update system CA certificates
sudo update-ca-certificates
echo "✓ AutoFirma CA certificate installed in system store"

# Clean up the certificate file as per original postinst
sudo rm -f "${AUTOFIRMA_DIR}/Autofirma_ROOT.crt"

# Step 4: Setup Firefox preferences for AutoFirma protocol
echo "Setting up Firefox AutoFirma preferences..."
if [ -f "/etc/firefox/pref/AutoFirma.js" ]; then
    echo "✓ Firefox AutoFirma preferences already exist"
else
    echo "INFO: /etc/firefox/pref/AutoFirma.js not found"
    echo "  This is normal for container environments - user preferences will be used instead"
fi

echo "=== AutoFirma Post-Installation Setup Complete ==="
echo "Note: AutoFirma CA certificate will be imported by configure-firefox.sh"
echo "=== AutoFirma Setup Complete - Ready for Protocol Handling ==="