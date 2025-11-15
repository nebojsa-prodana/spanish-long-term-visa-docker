#!/bin/bash
# Common variables used across all scripts
# Source this file in other scripts: source /usr/local/bin/common-vars.sh

# Directory paths
export AUTOFIRMA_DIR="/usr/lib/Autofirma"
export CERT_DIR="${CERT_DIR:-/certs}"
export FF_PROFILE="/home/autofirma/.mozilla/firefox/profile.default"
export FF_NSS_DB="dbm:${FF_PROFILE}"

# User NSS database (system-wide user certificate store)
export USER_NSS_DIR="/home/autofirma/.pki/nssdb"
export USER_NSS_DB="sql:${USER_NSS_DIR}"

# Certificate paths
export AUTOFIRMA_ROOT_CER="${AUTOFIRMA_DIR}/Autofirma_ROOT.cer"
export AUTOFIRMA_ROOT_CRT="/usr/local/share/ca-certificates/AutoFirma_ROOT.crt"

# AutoFirma configurator
export AUTOFIRMA_CONFIGURATOR="${AUTOFIRMA_DIR}/autofirmaConfigurador.jar"

# Desktop and MIME configuration
export APPLICATIONS_DIR="/usr/share/applications"
export AFIRMA_DESKTOP="${APPLICATIONS_DIR}/afirma.desktop"
