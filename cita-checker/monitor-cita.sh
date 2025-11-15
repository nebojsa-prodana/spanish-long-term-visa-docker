#!/bin/bash
# Continuous monitoring script for cita availability
# Runs check-cita.py every 30 minutes (configurable)

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${SCRIPT_DIR}/check-cita.py"
NOTIFY_SCRIPT="${SCRIPT_DIR}/notify.py"
ENV_FILE="${SCRIPT_DIR}/.env"

# Default check interval (30 minutes)
CHECK_INTERVAL_MINUTES=30

# Log file
MONITOR_LOG="/tmp/cita-monitor.log"

# PID file
PID_FILE="/tmp/cita-monitor.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $1" | tee -a "$MONITOR_LOG"
}

# Function to load .env file
load_env() {
    if [ -f "$ENV_FILE" ]; then
        log_message "Loading configuration from .env file..."
        # Export variables from .env file
        set -a
        source "$ENV_FILE"
        set +a
        return 0
    else
        return 1
    fi
}

# Function to check if monitor is already running
is_monitor_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" >/dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Function to stop the monitor
stop_monitor() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        log_message "Stopping cita monitor (PID: ${pid})..."
        kill "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
        log_message "Monitor stopped"
    else
        log_message "No monitor process found"
    fi
}

# Function to show monitor status
show_status() {
    if is_monitor_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${GREEN}✓ Monitor is running${NC} (PID: ${pid})"
        
        if [ -f "/tmp/cita-last-check" ]; then
            local last_check=$(cat "/tmp/cita-last-check")
            echo "Last check: ${last_check}"
        fi
        
        echo ""
        echo "Recent log entries:"
        tail -n 10 "$MONITOR_LOG" 2>/dev/null || echo "No log entries found"
    else
        echo -e "${YELLOW}○ Monitor is not running${NC}"
    fi
}

# Function to display usage information
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Monitor cita availability at Spanish police office by running periodic checks.

Commands:
  start         Start the monitoring service
  stop          Stop the monitoring service
  status        Show monitoring service status
  logs          Show recent log entries

Configuration:
  Two ways to configure:
  
  1. Using .env file (RECOMMENDED):
     - Copy .env.example to .env
     - Edit .env with your settings
     - Run: $0 start
  
  2. Using command-line options:
     - Pass all settings as command-line arguments
     - See examples below

Options for 'start' command (when not using .env):
  -p, --provincia PROVINCIA    Province name (required)
  -o, --oficina OFICINA        Police office ID or name (required)
  -t, --tramite TRAMITE        Tramite ID (required)
  -i, --interval MINUTES       Check interval in minutes (default: 30)

  Email Configuration (REQUIRED):
  --email-to EMAIL            Your email address (REQUIRED)
  --smtp-server SERVER        SMTP server hostname (REQUIRED)
  --smtp-port PORT            SMTP server port (default: 587)
  --smtp-user USERNAME        SMTP authentication username (REQUIRED)
  --smtp-pass PASSWORD        SMTP authentication password (REQUIRED)
  
  Optional Phone Notifications (Highly Recommended):
  --twilio-sid SID            Twilio Account SID for SMS/calls
  --twilio-token TOKEN        Twilio Auth Token
  --twilio-from NUMBER        Twilio phone number (from)
  --twilio-to NUMBER          Your phone number (to receive call)
  --call                      Enable phone call (requires Twilio)

  -h, --help                  Display this help message

Examples:
  # Using .env file (recommended - no arguments needed!)
  cp .env.example .env
  nano .env  # Edit your settings
  $0 start

  # Using command-line (email only)
  $0 start -p "Barcelona" -o "99" -t "4010" \\
     --email-to user@example.com \\
     --smtp-server smtp.gmail.com \\
     --smtp-user your-email@gmail.com \\
     --smtp-pass your-app-password

  # Using command-line (with phone call)
  $0 start -p "Barcelona" -o "99" -t "4010" \\
     --email-to user@example.com \\
     --smtp-server smtp.gmail.com \\
     --smtp-user your-email@gmail.com \\
     --smtp-pass your-app-password \\
     --twilio-sid ACxxxxx \\
     --twilio-token your_token \\
     --twilio-from +1234567890 \\
     --twilio-to +34XXXXXXXXX \\
     --call

  # Check status
  $0 status

  # View logs
  $0 logs

  # Stop monitoring
  $0 stop

Notes:
  - Email notifications are REQUIRED
  - Phone notifications highly recommended (free Twilio trial: \$15 credit)
  - Tramite 4010 = POLICÍA-TOMA DE HUELLAS (fingerprints)
  - Oficina 99 = Cualquier oficina (any office)
  - See .env.example for all tramite and oficina options

EOF
}

# Function to show logs
show_logs() {
    if [ -f "$MONITOR_LOG" ]; then
        tail -n 50 "$MONITOR_LOG"
    else
        echo "No log file found"
    fi
}

# Function to start monitoring
start_monitor() {
    # Load .env file if available
    load_env
    
    # Parse command-line arguments (override .env values)
    local provincia="${PROVINCIA:-}"
    local oficina="${OFICINA:-}"
    local tramite="${TRAMITE:-}"
    local interval="${CHECK_INTERVAL:-30}"
    
    # Parse command line args (they override .env)
    while [ $# -gt 0 ]; do
        case "$1" in
            -p|--provincia) provincia="$2"; shift 2 ;;
            -o|--oficina) oficina="$2"; shift 2 ;;
            -t|--tramite) tramite="$2"; shift 2 ;;
            -i|--interval) interval="$2"; shift 2 ;;
            *) shift ;;  # Keep other args for notify script
        esac
    done
    
    # Check if already running
    if is_monitor_running; then
        echo -e "${YELLOW}⚠ Monitor is already running${NC}"
        show_status
        exit 1
    fi
    
    # Validate parameters
    if [ -z "$provincia" ] || [ -z "$oficina" ] || [ -z "$tramite" ]; then
        echo -e "${RED}Error: Missing required parameters${NC}"
        echo ""
        if [ ! -f "$ENV_FILE" ]; then
            echo "No .env file found. Either:"
            echo "  1. Copy .env.example to .env and edit it, or"
            echo "  2. Provide command-line arguments"
            echo ""
        fi
        usage
        exit 1
    fi
    
    # Check if check script exists
    if [ ! -f "$CHECK_SCRIPT" ]; then
        echo -e "${RED}Error: Check script not found: ${CHECK_SCRIPT}${NC}"
        exit 1
    fi
    
    log_message "=========================================="
    log_message "Starting cita monitoring service"
    log_message "Provincia: ${provincia}"
    log_message "Oficina: ${oficina}"
    log_message "Tramite: ${tramite}"
    log_message "Check interval: ${interval} minutes"
    log_message "=========================================="
    
    # Start monitoring in background
    (
        # Save PID
        echo $$ > "$PID_FILE"
        
        # Main monitoring loop
        while true; do
            log_message "Running cita check..."
            
            # Run the check script
            if python3 "$CHECK_SCRIPT" \
                -p "$provincia" \
                -o "$oficina" \
                -t "$tramite" 2>&1 | tee -a "$MONITOR_LOG"; then
                
                log_message "${GREEN}✓✓✓ CITA FOUND! ✓✓✓${NC}"
                log_message "Sending URGENT notifications..."
                
                # Build notify script arguments from environment
                notify_args=()
                notify_args+=(-p "$provincia")
                
                # Add email config (required)
                [ -n "$EMAIL_TO" ] && notify_args+=(--email-to "$EMAIL_TO")
                [ -n "$SMTP_SERVER" ] && notify_args+=(--smtp-server "$SMTP_SERVER")
                [ -n "$SMTP_PORT" ] && notify_args+=(--smtp-port "$SMTP_PORT")
                [ -n "$SMTP_USER" ] && notify_args+=(--smtp-user "$SMTP_USER")
                [ -n "$SMTP_PASS" ] && notify_args+=(--smtp-pass "$SMTP_PASS")
                
                # Add Twilio config (optional)
                [ -n "$TWILIO_SID" ] && notify_args+=(--twilio-sid "$TWILIO_SID")
                [ -n "$TWILIO_TOKEN" ] && notify_args+=(--twilio-token "$TWILIO_TOKEN")
                [ -n "$TWILIO_FROM" ] && notify_args+=(--twilio-from "$TWILIO_FROM")
                [ -n "$TWILIO_TO" ] && notify_args+=(--twilio-to "$TWILIO_TO")
                [ "$ENABLE_CALL" = "true" ] && notify_args+=(--call)
                
                # Send multi-channel notifications
                python3 "$NOTIFY_SCRIPT" "${notify_args[@]}" 2>&1 | tee -a "$MONITOR_LOG"
                
                log_message ""
                log_message "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
                log_message "${GREEN}║                  🚨 CITA AVAILABLE NOW! 🚨                     ║${NC}"
                log_message "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
                log_message ""
                log_message ">>> Open VNC Browser: ${BLUE}http://localhost:8080/vnc.html${NC}"
                log_message ">>> Firefox is on the booking page - complete booking NOW!"
                log_message ">>> Appointments fill within 5-10 minutes!"
                log_message ""
                log_message "Check /tmp/CITA_AVAILABLE_NOW.txt for details"
                log_message ""
                
                # Stop monitoring after finding cita
                log_message "Stopping monitor - cita found!"
                break
            else
                local exit_code=$?
                if [ $exit_code -eq 1 ]; then
                    log_message "${YELLOW}○ No citas available${NC}"
                else
                    log_message "${YELLOW}⚠ Check completed with warnings${NC}"
                fi
            fi
            
            # Calculate seconds to sleep
            local sleep_seconds=$((interval * 60))
            log_message "Next check in ${interval} minutes (at $(date -d "+${interval} minutes" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v+${interval}M '+%Y-%m-%d %H:%M:%S'))..."
            
            sleep "$sleep_seconds"
        done
        
        # Cleanup
        rm -f "$PID_FILE"
    ) &
    
    local monitor_pid=$!
    
    echo -e "${GREEN}✓ Monitor started${NC} (PID: ${monitor_pid})"
    echo "Check interval: ${interval} minutes"
    echo "Log file: ${MONITOR_LOG}"
    echo ""
    echo "Use '$0 status' to check status"
    echo "Use '$0 stop' to stop monitoring"
    echo "Use '$0 logs' to view logs"
}

# Main script logic
COMMAND="${1:-}"
shift || true

case "$COMMAND" in
    start)
        # Pass all remaining arguments to start_monitor
        # It will handle .env loading and command-line overrides
        start_monitor "$@"
        ;;
    stop)
        stop_monitor
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    "")
        echo -e "${RED}Error: No command specified${NC}"
        echo ""
        usage
        exit 1
        ;;
    *)
        echo -e "${RED}Error: Unknown command: ${COMMAND}${NC}"
        echo ""
        usage
        exit 1
        ;;
esac
