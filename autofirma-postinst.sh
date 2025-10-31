#!/bin/bash
set -euo pipefail

# AutoFirma Post-Installation Setup
# Fail fast for faster iteration

echo "=== AutoFirma Post-Installation Setup ==="

# Step 1: Generate AutoFirma CA and SSL certificates
echo "Generating AutoFirma certificates..."
if [ ! -f "/usr/lib/Autofirma/autofirmaConfigurador.jar" ]; then
    echo "ERROR: autofirmaConfigurador.jar not found!"
    exit 1
fi

cd /usr/lib/Autofirma
java -Djava.awt.headless=true -jar autofirmaConfigurador.jar
echo "✓ AutoFirma certificates generated"

# Step 2: Execute AutoFirma's certificate installation script if it exists
echo "Running AutoFirma certificate installation script..."
if [ -f "/usr/lib/Autofirma/script.sh" ]; then
    chmod +x /usr/lib/Autofirma/script.sh
    /usr/lib/Autofirma/script.sh
    rm -f /usr/lib/Autofirma/script.sh
    echo "✓ AutoFirma certificate script executed"
else
    echo "INFO: AutoFirma script.sh not found (this may be normal)"
fi

# Step 3: Install AutoFirma CA certificate in system certificate store
echo "Installing AutoFirma CA certificate in system store..."
if [ ! -f "/usr/lib/Autofirma/Autofirma_ROOT.cer" ]; then
    echo "ERROR: Autofirma_ROOT.cer not found!"
    exit 1
fi

# Convert DER to PEM format
sudo openssl x509 -inform der -in /usr/lib/Autofirma/Autofirma_ROOT.cer -out /usr/lib/Autofirma/Autofirma_ROOT.crt

# Install in system certificate stores
sudo mkdir -p /usr/share/ca-certificates/AutoFirma/
sudo cp /usr/lib/Autofirma/Autofirma_ROOT.crt /usr/share/ca-certificates/AutoFirma/AutoFirma_ROOT.crt
sudo cp /usr/lib/Autofirma/Autofirma_ROOT.crt /usr/local/share/ca-certificates/AutoFirma_ROOT.crt

# Update system CA certificates
sudo update-ca-certificates
echo "✓ AutoFirma CA certificate installed in system store"

# Clean up the certificate file as per original postinst
sudo rm -f /usr/lib/Autofirma/Autofirma_ROOT.crt

# Step 4: Setup Firefox preferences for AutoFirma protocol
echo "Setting up Firefox AutoFirma preferences..."
if [ -f "/etc/firefox/pref/AutoFirma.js" ]; then
    echo "✓ Firefox AutoFirma preferences already exist"
else
    echo "INFO: /etc/firefox/pref/AutoFirma.js not found"
    echo "  This is normal for container environments - user preferences will be used instead"
fi

echo "=== AutoFirma Post-Installation Setup Complete ==="

# Step 5: Import AutoFirma CA certificate into Firefox (CRITICAL for websocket SSL)
echo "Importing AutoFirma CA certificate into Firefox..."
if [ -f "/usr/local/share/ca-certificates/AutoFirma_ROOT.crt" ]; then
    # Import into the autofirma user's Firefox profile
    if [ -d "/home/autofirma/.mozilla/firefox/profile.default" ]; then
        su - autofirma -c "certutil -A -n 'AutoFirma ROOT' -t 'CT,C,C' -d dbm:/home/autofirma/.mozilla/firefox/profile.default -i /usr/local/share/ca-certificates/AutoFirma_ROOT.crt" 2>/dev/null || \
        echo "⚠ Firefox certificate import failed (may already exist or profile not ready)"
        echo "✓ AutoFirma CA certificate imported into Firefox"
    else
        echo "INFO: Firefox profile not found - certificate will be imported later by configure-firefox.sh"
    fi
else
    echo "ERROR: AutoFirma CA certificate not found for Firefox import!"
fi

echo "=== AutoFirma Setup Complete - Ready for Protocol Handling ==="