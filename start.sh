#!/bin/bash
set -e

# Load common variables
source /usr/local/bin/common-vars.sh

# --- Add troubleshooting tools to .bashrc for persistent sessions ---
echo "source /usr/local/bin/troubleshoot.sh" >> ~/.bashrc

# Source troubleshooting tools for current session
source /usr/local/bin/troubleshoot.sh

# --- Run smoke tests ---
/usr/local/bin/smoketest.sh

# --- Configure Firefox to disable updates ---
/usr/local/bin/configure-firefox.sh

# --- Run AutoFirma post-installation setup (generates CA and SSL certs) ---
echo "Running AutoFirma post-installation setup..."
/usr/local/bin/autofirma-postinst.sh

# --- Certificate import ---
if [ -d "$CERT_DIR" ]; then
  # Setup Firefox NSS database
  echo "Setting up Firefox certificate database..."
  mkdir -p "$FF_PROFILE"
  chown -R autofirma:autofirma "$FF_PROFILE"
  
  # Initialize legacy NSS database (Firefox ESR 52 compatibility)
  if [ ! -f "$FF_PROFILE/cert8.db" ]; then
    certutil -N -d "$FF_NSS_DB" --empty-password 2>/dev/null || true
    echo "✓ Legacy Firefox certificate database initialized"
  fi
  
  # Import AutoFirma CA certificate into Firefox (required for SSL websocket connection)
  if [ -f "$AUTOFIRMA_ROOT_CRT" ]; then
    echo "Importing AutoFirma CA certificate into Firefox NSS database..."
    certutil -A -n "AutoFirma ROOT" -t "CT,C,C" -d "$FF_NSS_DB" -i "$AUTOFIRMA_ROOT_CRT" 2>/dev/null || \
    echo "⚠ AutoFirma CA certificate import failed (may already exist)"
    echo "✓ AutoFirma CA certificate imported into Firefox"
  fi
  
  # Setup user system NSS database (for user certificates)
  echo "Setting up user NSS certificate database..."
  mkdir -p "$USER_NSS_DIR"
  chown -R autofirma:autofirma "$USER_NSS_DIR"
  
  # Initialize user NSS database (modern SQL format)
  if [ ! -f "$USER_NSS_DIR/cert9.db" ]; then
    certutil -N -d "$USER_NSS_DB" --empty-password 2>/dev/null || true
    echo "✓ User NSS certificate database initialized"
  fi
  
  # Import AutoFirma CA certificate into user NSS database
  if [ -f "$AUTOFIRMA_ROOT_CRT" ]; then
    echo "Importing AutoFirma CA certificate into user NSS database..."
    certutil -A -n "AutoFirma ROOT" -t "CT,C,C" -d "$USER_NSS_DB" -i "$AUTOFIRMA_ROOT_CRT" 2>/dev/null || \
    echo "⚠ AutoFirma CA certificate import failed (may already exist)"
    echo "✓ AutoFirma CA certificate imported into user NSS"
  fi
  
  # Import user certificates into user NSS database
  echo "Importing user certificates..."
  for certfile in "$CERT_DIR"/*.p12 "$CERT_DIR"/*.pfx; do
    [ -e "$certfile" ] || continue
    echo "Processing $certfile..."
    echo "  → User NSS database..."
    pk12util -i "$certfile" -d "$USER_NSS_DB" && echo "    ✓ Imported to user NSS" || echo "    ✗ Failed to import to user NSS"
    echo "  → Firefox NSS database..."
    pk12util -i "$certfile" -d "$FF_NSS_DB" && echo "    ✓ Imported to Firefox" || echo "    ✗ Failed to import to Firefox"
  done
  
  # Show imported certificates
  echo ""
  echo "Certificates in user NSS database:"
  certutil -L -d "$USER_NSS_DB" 2>/dev/null | grep -v "Certificate Nickname" | grep -v "^$" || echo "No certificates found"
  echo ""
  echo "Certificates in Firefox database:"
  certutil -L -d "$FF_NSS_DB" 2>/dev/null | grep -v "Certificate Nickname" | grep -v "^$" || echo "No certificates found"
fi

# --- Start graphical environment ---
echo "Starting desktop environment..."
Xvfb :0 -screen 0 1280x800x24 >/dev/null 2>&1 &
sleep 2
dbus-launch openbox >/dev/null 2>&1 &
sleep 1

# NOTE: AutoFirma will be started on-demand by Firefox when afirma:// URLs are clicked
# No need to start it as a service here

x11vnc -display :0 -nopw -forever -shared -ncache 10 -ncache_cr -defer 1 >/dev/null 2>&1 &
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
