# Cita Checker for Toma de Huellas

After your long-term residence application is approved, you need to book an appointment (cita) at a police office for fingerprinting (toma de huellas).

## How It Works

1. Scripts run inside Docker container every 30 minutes
2. Uses Selenium to automate Firefox with your digital certificate  
3. Checks https://icp.administracionelectronica.gob.es/icpplustieb for appointments
4. When appointment found:
   - **Sends multi-channel URGENT notifications**
   - **Stops monitoring**
   - **Leaves browser on booking page**
   - **You complete booking via VNC browser**

## Notification Channels

### Required (Email)
- Email with urgent message and direct VNC link
- HTML formatted with clear instructions

### Optional but Highly Recommended
- **SMS via Twilio** - Text message alert
- **Phone Call via Twilio** - Automated voice call (most aggressive!)
- **Urgent file** - Creates `/tmp/CITA_AVAILABLE_NOW.txt`

## Quick Start

### Simple Configuration (Recommended)

```bash
# 1. Start Docker container
make run

# 2. Open shell in container
make shell

# 3. Copy and configure .env file
cp /workspace/cita-checker/.env.example /workspace/cita-checker/.env
nano /workspace/cita-checker/.env  # Edit with your settings

# 4. Start monitoring (reads .env automatically!)
/workspace/cita-checker/monitor-cita.sh start
```

### What to Configure in .env

**Required Settings:**
```bash
# Location
PROVINCIA="Barcelona"
OFICINA="16"           # 16 = Rambla Guipúscoa (preferred) or 99 = Any office
TRAMITE="4010"         # 4010 = POLICÍA-TOMA DE HUELLAS

# Email (REQUIRED)
EMAIL_TO="your-email@gmail.com"
SMTP_SERVER="smtp.gmail.com"
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"
```

**Optional but Highly Recommended (Twilio):**
```bash
# Phone notifications (free $15 trial!)
TWILIO_SID="ACxxxxxxxxxxxxx"
TWILIO_TOKEN="your_auth_token"
TWILIO_FROM="+1234567890"
TWILIO_TO="+34XXXXXXXXX"
ENABLE_CALL="true"     # Set to true for phone calls
```

### Manual Configuration (Command Line)

If you prefer command-line arguments over .env file:

```bash
/workspace/cita-checker/monitor-cita.sh start \
  -p "Barcelona" \
  -o "Barcelona" \
# Email only (minimum)
/workspace/cita-checker/monitor-cita.sh start \
  -p "Barcelona" \
  -o "99" \
  -t "4010" \
  --email-to your-email@gmail.com \
  --smtp-server smtp.gmail.com \
  --smtp-user your-email@gmail.com \
  --smtp-pass your-app-password

# Email + Phone call (recommended)
/workspace/cita-checker/monitor-cita.sh start \
  -p "Barcelona" \
  -o "99" \
  -t "4010" \
  --email-to your-email@gmail.com \
  --smtp-server smtp.gmail.com \
  --smtp-user your-email@gmail.com \
  --smtp-pass your-app-password \
  --twilio-sid ACxxxxxxxxxxxxx \
  --twilio-token your_auth_token \
  --twilio-from +1234567890 \
  --twilio-to +34XXXXXXXXX \
  --call
```

## Email Setup (Gmail)

1. Enable 2-factor authentication
2. Generate app password: https://myaccount.google.com/apppasswords
3. Use these settings:
   - Server: `smtp.gmail.com`
   - Port: `587`
   - User: your-email@gmail.com
   - Pass: your-app-password

## Twilio Setup (FREE Tier Available)

Twilio provides SMS and voice calls. Free trial includes $15 credit.

### 1. Create Twilio Account
- Go to: https://www.twilio.com/try-twilio
- Sign up (credit card required but NOT charged for trial)
- Get $15 free credit (enough for ~500 SMS or ~150 calls)

### 2. Get Credentials
- **Account SID**: Found on Twilio dashboard
- **Auth Token**: Found on Twilio dashboard  
- **From Number**: Get a free trial number from Twilio

### 3. Verify Your Phone
- Add your phone number to "Verified Caller IDs"
- Twilio will send verification code

### 4. Use in .env or Command Line
```bash
# In .env file:
TWILIO_SID="ACxxxxxxxxxxxxx"
TWILIO_TOKEN="your_auth_token"
TWILIO_FROM="+1234567890"
TWILIO_TO="+34XXXXXXXXX"
ENABLE_CALL="true"

# Or command line:
--twilio-sid ACxxxxxxxxxxxxx \
--twilio-token your_auth_token \
--twilio-from +1234567890 \
--twilio-to +34XXXXXXXXX \
--call
```

## Configuration Options

### Tramite Types (TRAMITE)
See `.env.example` for full list. Common ones:
- `4010` - POLICÍA-TOMA DE HUELLAS (fingerprints after visa approval) ⭐ **DEFAULT**
- `4036` - POLICÍA-RECOGIDA DE TARJETA (TIE card pickup)
- `4046` - TOMA DE HUELLAS (EXPEDICIÓN DE TARJETA) Y RENOVACIÓN

### Barcelona Oficinas (OFICINA)
See `.env.example` for all 27 locations. Popular choices:
- `99` - Cualquier oficina (any office) ⭐ **DEFAULT**
- `16` - Rambla Guipuscoa, 74 ⭐ **RECOMMENDED**
- `17` - Murcia, 42
- `18` - Mallorca, 213

## Editing Scripts Without Rebuild

The `cita-checker/` folder is mounted into the container, so you can edit scripts on your host machine and changes take effect immediately:

```bash
# Edit on host machine
nano cita-checker/.env              # Update configuration
nano cita-checker/check-cita.py     # Modify check logic
nano cita-checker/monitor-cita.sh   # Change monitoring behavior
nano cita-checker/notify.py         # Adjust notifications

# Changes available immediately in container
# No rebuild needed!
```

## Commands

```bash
# Start monitoring (reads .env)
/workspace/cita-checker/monitor-cita.sh start

# Check status
/workspace/cita-checker/monitor-cita.sh status

# View logs
/workspace/cita-checker/monitor-cita.sh logs

# Stop monitoring
/workspace/cita-checker/monitor-cita.sh stop
```

## When Cita is Found

You'll receive notifications via ALL configured channels:

1. **Email** - Check your inbox
2. **SMS** (if configured) - Check your phone
3. **Phone Call** (if configured) - Answer the call!
4. **File** - `/tmp/CITA_AVAILABLE_NOW.txt` created

### What To Do:
1. **Open VNC**: http://localhost:8080/vnc.html
2. **Firefox is on booking page** - complete immediately!
3. **Appointments fill in 5-10 minutes** - act FAST!

## Parameters

### Required
- `-p, --provincia` - Province name
- `-o, --oficina` - Police office name
- `-t, --tramite` - "POLICIA-TOMA DE HUELLAS"

### Required (Email)
- `--email-to` - Your email
- `--smtp-server` - SMTP server
- `--smtp-port` - SMTP port (default: 587)
- `--smtp-user` - SMTP username
- `--smtp-pass` - SMTP password

### Optional but Recommended (Twilio)
- `--twilio-sid` - Account SID
- `--twilio-token` - Auth token
- `--twilio-from` - Twilio phone number
- `--twilio-to` - Your phone number
- `--call` - Make phone call (most aggressive!)

### Optional
- `-i, --interval` - Check interval in minutes (default: 30)

## Logs & Files

- **Monitor log**: `/tmp/cita-monitor.log`
- **Checker log**: `/tmp/cita-checker-selenium.log`  
- **Screenshots**: `/tmp/cita-screenshots/`
- **Urgent file**: `/tmp/CITA_AVAILABLE_NOW.txt` (created when found)

```bash
# Tail logs
tail -f /tmp/cita-monitor.log

# View urgent file
cat /tmp/CITA_AVAILABLE_NOW.txt
```

## Troubleshooting

### Check if monitoring is running
```bash
/workspace/cita-checker/monitor-cita.sh status
```

### Test notifications manually
```bash
python3 /workspace/cita-checker/notify.py \
  -p "Barcelona" \
  --email-to your@email.com \
  --smtp-server smtp.gmail.com \
  --smtp-user your@email.com \
  --smtp-pass your-pass
```

### Verify Twilio
```bash
python3 -c "from twilio.rest import Client; print('Twilio OK')"
```

### Check Selenium
```bash
python3 -c "from selenium import webdriver; print('Selenium OK')"
geckodriver --version
```

## Important Notes

⚠️ **Email is REQUIRED** - System won't start without email config

⚠️ **Check VNC immediately** - http://localhost:8080/vnc.html

⚠️ **Act within 5-10 minutes** - Appointments disappear fast

⚠️ **Monitor stops automatically** - After finding cita

⚠️ **Free Twilio credit** - $15 free, enough for many notifications

⚠️ **Edit without rebuild** - Scripts mounted from host

## Example Workflow

1. **Start Container** (mounts cita-checker/)
   ```bash
   make run
   ```

2. **Keep VNC open** in browser
   ```
   http://localhost:8080/vnc.html
   ```

3. **Start Monitor** with all notifications
   ```bash
   make shell
   /workspace/cita-checker/monitor-cita.sh start \
     -p "Barcelona" \
     -o "Barcelona" \
     -t "POLICIA-TOMA DE HUELLAS" \
     --email-to your@email.com \
     --smtp-server smtp.gmail.com \
     --smtp-user your@email.com \
     --smtp-pass your-pass \
     --twilio-sid ACxxx \
     --twilio-token token \
     --twilio-from +1234567890 \
     --twilio-to +0987654321 \
     --call
   ```

4. **Wait** - You'll be notified multiple ways when found

5. **When notified** - Open VNC, complete booking immediately

6. **Done!** - Monitor stops automatically

## Cost Breakdown

- **Email**: FREE (Gmail, Outlook, etc.)
- **Twilio SMS**: ~$0.0075/message ($15 free = ~2000 messages)
- **Twilio Call**: ~$0.013/minute ($15 free = ~1150 minutes)
- **System alerts**: FREE
- **Docker**: FREE

**Total**: Effectively FREE with Twilio trial credit!
