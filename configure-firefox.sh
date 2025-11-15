#!/bin/bash
# Firefox Configuration Script - Disable updates and annoying dialogs
# Enhanced with AutoFirma integration based on https://github.com/xmartinez/autofirma-docker

# Load common variables
source /usr/local/bin/common-vars.sh

USER_JS="$FF_PROFILE/user.js"

echo "Configuring Firefox to disable updates and dialogs..."

# Ensure profile directory exists
mkdir -p "$FF_PROFILE"

# Setup p11-kit trust module for proper certificate handling
echo "Setting up p11-kit trust module..."
modutil -list p11-kit-trust -dbdir "$FF_PROFILE" >&/dev/null || \
modutil -force -add p11-kit-trust -dbdir "$FF_PROFILE" -libfile /usr/lib/x86_64-linux-gnu/pkcs11/p11-kit-trust.so

# Create profiles.ini
cat > "/home/autofirma/.mozilla/firefox/profiles.ini" << 'EOF'
[Profile0]
Name=default
IsRelative=1
Path=profile.default
EOF

# Create user.js with minimal preferences to disable updates and enable Java
# Enhanced AutoFirma protocol handling
cat > "$USER_JS" << 'EOF'
// Disable Firefox updates (stops the popup)
user_pref("app.update.enabled", false);
user_pref("app.update.auto", false);

// Enable Java plugin (required for government site)
user_pref("plugin.state.java", 2);
user_pref("plugins.click_to_play", false);

// Skip first-run dialogs
user_pref("browser.rights.3.shown", true);
user_pref("browser.startup.homepage_override.mstone", "ignore");

// AutoFirma protocol integration - CRITICAL for invoking AutoFirma
user_pref("network.protocol-handler.expose.afirma", false);
user_pref("network.protocol-handler.external.afirma", true);
user_pref("network.protocol-handler.warn-external.afirma", false);

EOF

# Set proper ownership
chown autofirma:autofirma "$USER_JS"
chmod 644 "$USER_JS"

echo "✓ Firefox configured to disable updates and dialogs"