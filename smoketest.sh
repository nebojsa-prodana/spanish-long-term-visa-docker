#!/bin/bash
#!/bin/bash
# Spanish Visa Container - Smoke Tests
# Validate that all critical components are in place and ready

# Load common variables
source /usr/local/bin/common-vars.sh
# This script performs basic system validation

echo "🔍 Running smoke tests..."

# Test Java VM
echo -n "Testing Java VM... "
if java -version >/dev/null 2>&1; then
    echo "✓ Java working"
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
    echo "   Version: $JAVA_VERSION"
else
    echo "❌ Java failed"
    exit 1
fi

# Test Firefox
echo -n "Testing Firefox... "
if firefox --version >/dev/null 2>&1; then
    echo "✓ Firefox available"
    FIREFOX_VERSION=$(firefox --version 2>/dev/null | cut -d' ' -f3)
    echo "   Version: $FIREFOX_VERSION"
else
    echo "❌ Firefox failed"
    exit 1
fi

# Test AutoFirma
echo -n "Testing AutoFirma... "
if which autofirma >/dev/null 2>&1; then
    echo "✓ AutoFirma installed"
    echo "   Path: $(which autofirma)"
else
    echo "❌ AutoFirma missing"
    exit 1
fi

# Test X11 display setup
echo -n "Testing X11 display... "
if xdpyinfo -display :0 >/dev/null 2>&1; then
    echo "✓ X11 display ready"
else
    echo "⚠ X11 display not ready (will be started automatically)"
fi

# Test VNC components
echo -n "Testing VNC components... "
if which x11vnc >/dev/null 2>&1 && which python3 >/dev/null 2>&1; then
    echo "✓ VNC tools available"
else
    echo "❌ VNC tools missing"
    exit 1
fi

# Test noVNC web interface
echo -n "Testing noVNC... "
if [ -d "/usr/share/novnc" ]; then
    echo "✓ noVNC installed"
else
    echo "❌ noVNC missing"
    exit 1
fi

# Test certificate tools
echo -n "Testing certificate tools... "
if which certutil >/dev/null 2>&1 && which pk12util >/dev/null 2>&1; then
    echo "✓ NSS tools available"
else
    echo "❌ Certificate tools missing"
    exit 1
fi

# Test Firefox profile directory
echo -n "Testing Firefox profile... "
if [ -d "/home/autofirma/.mozilla/firefox" ]; then
    echo "✓ Firefox profile directory exists"
else
    echo "⚠ Firefox profile directory missing (will be created)"
fi

# Test certificate directory
echo -n "Testing certificate directory... "
if [ -d "$CERT_DIR" ]; then
    CERT_COUNT=$(find "$CERT_DIR" -name "*.p12" -o -name "*.pfx" 2>/dev/null | wc -l)
    echo "✓ Certificate directory mounted"
    echo "   Found $CERT_COUNT certificate files"
else
    echo "⚠ Certificate directory not mounted at $CERT_DIR"
fi

# Test permissions
echo -n "Testing user permissions... "
if [ "$(whoami)" = "autofirma" ]; then
    echo "✓ Running as autofirma user"
else
    echo "⚠ Running as $(whoami) instead of autofirma"
fi

echo ""
echo "✅ Smoke tests completed successfully!"
echo ""