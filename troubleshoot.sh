#!/bin/bash
# Spanish Visa Container - Troubleshooting Tools
# This script provides debugging and troubleshooting commands

# --- Environment setup ---
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/default-java}
export PATH=$JAVA_HOME/bin:/opt/firefox:$PATH
export DISPLAY=${DISPLAY:-:0}
export CERT_DIR=${CERT_DIR:-/certs}
export FF_CERTDB="/home/autofirma/.mozilla/firefox/profile.default"
# Using legacy DBM format for Firefox ESR 52 compatibility
export FF_NSS_DB="dbm:$FF_CERTDB"

# Spanish government URLs
export VISA_SITE="https://sede.administracionespublicas.gob.es/mercurio/inicioMercurio.html"
export AUTOFIRMA_SITE="https://firmaelectronica.gob.es/"

# --- Helpful aliases and functions ---

# Main help command
visa-help() {
    echo ""
    echo "🇪🇸 Spanish Visa Container - Available Commands:"
    echo ""
    echo "🌐 Website Access:"
    echo "   firefox-spanish    - Open Spanish visa website"
    echo "   vnc-web           - Show VNC web access URL"
    echo ""
    echo "📋 Certificate Management:"
    echo "   cert-list         - List all certificates in Firefox"
    echo "   cert-verify       - Show personal certificates only"
    echo "   cert-import-help  - Show how to import certificates"
    echo "   cert-debug        - Debug certificate database issues"
    echo ""
    echo "🔧 System Diagnostics:"
    echo "   java-test         - Test Java installation"
    echo "   firefox-test      - Test Firefox installation"
    echo "   autofirma-test    - Test AutoFirma installation"
    echo "   display-test      - Test X11 display"
    echo "   smoke-test        - Run complete system validation"
    echo ""
    echo "🐛 Advanced Troubleshooting:"
    echo "   cert-raw          - Show raw certificate database content"
    echo "   firefox-profile   - Show Firefox profile information"
    echo "   system-info       - Show system environment"
    echo ""
}

# Website commands
alias firefox-spanish='DISPLAY=:0 firefox "$VISA_SITE" &'
alias vnc-web='echo "VNC Web Access: http://localhost:8080/vnc.html"'

# Certificate commands - using legacy database format
alias cert-list='certutil -L -d "$FF_NSS_DB"'
alias cert-verify='certutil -L -d "$FF_NSS_DB" | grep -E "(u,u,u|Certificate Nickname)"'

cert-import-help() {
    echo "📁 Certificate Import Instructions:"
    echo "1. Place your .p12 or .pfx files in: $CERT_DIR"
    echo "2. Restart the container: docker restart <container_name>"
    echo "3. Check import: cert-list"
    echo ""
    echo "💡 Supported formats: .p12, .pfx"
    echo "📂 Import directory: $CERT_DIR"
}

cert-debug() {
    echo "🔍 Certificate Database Debugging:"
    echo ""
    echo "Database path: $FF_NSS_DB"
    echo "Profile directory: $FF_CERTDB"
    echo ""
    echo "Database files:"
    ls -la "$FF_CERTDB"/{cert8.db,key3.db,secmod.db} 2>/dev/null || echo "⚠ Legacy database files missing"
    echo ""
    echo "Certificate count:"
    local cert_count=$(certutil -L -d "$FF_NSS_DB" 2>/dev/null | grep -v "Certificate Nickname" | grep -v "^$" | wc -l)
    echo "Found $cert_count certificates"
    echo ""
    echo "Personal certificates (u,u,u trust):"
    certutil -L -d "$FF_NSS_DB" 2>/dev/null | grep "u,u,u" || echo "No personal certificates found"
}

# System diagnostic commands
java-test() {
    echo "☕ Java Test:"
    java -version 2>&1 | head -3
    echo "Java Home: $JAVA_HOME"
    echo "Java in PATH: $(which java)"
}

firefox-test() {
    echo "🦊 Firefox Test:"
    firefox --version 2>/dev/null || echo "❌ Firefox not working"
    echo "Firefox path: $(which firefox)"
    echo "Firefox profile: $FF_CERTDB"
}

autofirma-test() {
    echo "🔐 AutoFirma Test:"
    which autofirma >/dev/null && echo "✅ AutoFirma found: $(which autofirma)" || echo "❌ AutoFirma not found"
    autofirma --version 2>/dev/null || echo "❌ AutoFirma version check failed"
}

display-test() {
    echo "🖥️  Display Test:"
    echo "DISPLAY variable: $DISPLAY"
    xdpyinfo -display :0 >/dev/null 2>&1 && echo "✅ X11 display working" || echo "❌ X11 display not working"
    ps aux | grep -E "(Xvfb|x11vnc)" | grep -v grep || echo "⚠ Display services not running"
}

smoke-test() {
    echo "🔍 Running comprehensive system validation..."
    /usr/local/bin/smoketest.sh
}

# Advanced troubleshooting
cert-raw() {
    echo "📋 Raw Certificate Database Content:"
    echo ""
    echo "=== Legacy Database (cert8.db) ==="
    certutil -L -d "$FF_NSS_DB" 2>/dev/null || echo "Cannot read legacy database"
    echo ""
    echo "=== Database File Sizes ==="
    ls -lh "$FF_CERTDB"/{cert8.db,key3.db,secmod.db} 2>/dev/null || echo "Database files missing"
}

firefox-profile() {
    echo "🦊 Firefox Profile Information:"
    echo ""
    echo "Profile directory: $FF_CERTDB"
    echo "profiles.ini content:"
    cat /home/autofirma/.mozilla/firefox/profiles.ini 2>/dev/null || echo "profiles.ini not found"
    echo ""
    echo "Profile contents:"
    ls -la "$FF_CERTDB" 2>/dev/null | head -10
    echo ""
    echo "Certificate database format:"
    [ -f "$FF_CERTDB/cert8.db" ] && echo "✅ Legacy format (cert8.db)" || echo "❌ Legacy format missing"
    [ -f "$FF_CERTDB/cert9.db" ] && echo "⚠ Modern format (cert9.db) also present" || echo "✅ No modern format conflicts"
}

system-info() {
    echo "🔧 System Environment Information:"
    echo ""
    echo "User: $(whoami)"
    echo "Home: $HOME"
    echo "Working directory: $(pwd)"
    echo ""
    echo "Environment variables:"
    echo "  JAVA_HOME=$JAVA_HOME"
    echo "  DISPLAY=$DISPLAY"
    echo "  CERT_DIR=$CERT_DIR"
    echo "  FF_CERTDB=$FF_CERTDB"
    echo "  FF_NSS_DB=$FF_NSS_DB"
    echo ""
    echo "Container uptime: $(uptime)"
}

# Quick certificate import function
cert-import-manual() {
    if [ -z "$1" ]; then
        echo "Usage: cert-import-manual /path/to/certificate.p12"
        return 1
    fi
    
    if [ ! -f "$1" ]; then
        echo "❌ Certificate file not found: $1"
        return 1
    fi
    
    echo "📋 Manually importing certificate: $1"
    pk12util -i "$1" -d "$FF_NSS_DB" && echo "✅ Import successful" || echo "❌ Import failed"
}

# Export functions and aliases so they're available in interactive shells
export -f visa-help cert-import-help cert-debug java-test firefox-test autofirma-test display-test
export -f cert-raw firefox-profile system-info cert-import-manual smoke-test

# Welcome message for interactive sessions
if [[ $- == *i* ]]; then
    echo ""
    echo "🇪🇸 Spanish Visa Container Environment Ready!"
    echo "📋 Type 'visa-help' for available commands"
    echo "🌐 Access GUI: http://localhost:8080/vnc.html"
    echo "📁 Certificates: $CERT_DIR"
    echo ""
fi

echo "Spanish Visa Container Environment Loaded ✓"