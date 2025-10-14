#!/bin/bash
# Firefox Configuration Script - Disable updates and annoying dialogs

FF_PROFILE="/home/autofirma/.mozilla/firefox/profile.default"
USER_JS="$FF_PROFILE/user.js"

echo "Configuring Firefox to disable updates and dialogs..."

# Ensure profile directory exists
mkdir -p "$FF_PROFILE"

# Create user.js with minimal preferences to disable updates and enable Java
# Only the essentials for Firefox ESR 52 to work with Spanish government site
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
EOF

# Set proper ownership
chown autofirma:autofirma "$USER_JS"
chmod 644 "$USER_JS"

echo "✓ Firefox configured to disable updates and dialogs"