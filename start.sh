#!/bin/bash
set -e

# --- Environment setup ---
CERT_DIR=${CERT_DIR:-/certs}
FF_CERTDB="/home/autofirma/.mozilla/firefox/profile.default"
# NOTE: Using legacy DBM format (cert8.db) instead of modern SQL format (cert9.db)
# Firefox ESR 52 uses the legacy format
FF_NSS_DB="dbm:${FF_CERTDB}"

# --- Add troubleshooting tools to .bashrc for persistent sessions ---
echo "source /usr/local/bin/troubleshoot.sh" >> ~/.bashrc

# Source troubleshooting tools for current session
source /usr/local/bin/troubleshoot.sh

# --- Run smoke tests ---
/usr/local/bin/smoketest.sh

# --- Configure Firefox to disable updates ---
/usr/local/bin/configure-firefox.sh

# --- Certificate import ---
if [ -d "$CERT_DIR" ]; then
  echo "Setting up Firefox certificate database..."
  mkdir -p "$FF_CERTDB"
  chown -R autofirma:autofirma "$FF_CERTDB"
  
  # Initialize legacy NSS database (Firefox ESR 52 compatibility)
  if [ ! -f "$FF_CERTDB/cert8.db" ]; then
    printf '\n\n' | certutil -N -d "$FF_NSS_DB" 2>/dev/null || true
    echo "✓ Legacy certificate database initialized"
  fi
  
  # Import certificates
  for certfile in "$CERT_DIR"/*.p12 "$CERT_DIR"/*.pfx; do
    [ -e "$certfile" ] || continue
    echo "Importing $certfile into legacy database..."
    pk12util -i "$certfile" -d "$FF_NSS_DB" && echo "✓ Certificate imported" || echo "✗ Import failed"
  done
  
  # Show imported certificates
  echo "Certificates in Firefox database:"
  certutil -L -d "$FF_NSS_DB" 2>/dev/null | grep -v "Certificate Nickname" | grep -v "^$" || echo "No certificates found"
fi

# --- Start graphical environment ---
echo "Starting desktop environment..."
Xvfb :0 -screen 0 1280x800x24 >/dev/null 2>&1 &
sleep 2
dbus-launch openbox >/dev/null 2>&1 &
sleep 1
x11vnc -display :0 -nopw -forever -quiet -shared >/dev/null 2>&1 &
python3 -m websockify --web=/usr/share/novnc 8080 localhost:5900 >/dev/null 2>&1 &

sleep 3
echo "Opening Spanish government visa website..."
DISPLAY=:0 firefox "$VISA_SITE" >/dev/null 2>&1 &

echo ""
echo "🎉 Spanish Visa Container Ready!"
echo "🌐 Access Firefox: http://localhost:8080/vnc.html"
echo "📋 Your certificates should be visible in Firefox Certificate Manager"
echo "💡 Type 'visa-help' for troubleshooting commands"
echo ""

wait
