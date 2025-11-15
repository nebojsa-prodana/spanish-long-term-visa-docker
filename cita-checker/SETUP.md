# Cita Checker - Quick Setup Guide

## 🎯 What This Does

Automatically checks for Spanish police appointment availability every 30 minutes and aggressively notifies you when found.

## ⚡ 3-Minute Setup

### 1. Start Container
```bash
make run
make shell
```

### 2. Configure Settings
```bash
cd /workspace/cita-checker
cp .env.example .env
nano .env
```

Edit these **REQUIRED** settings:
```bash
# Your email (REQUIRED for notifications)
EMAIL_TO="your-email@gmail.com"
SMTP_SERVER="smtp.gmail.com"
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"  # Get from: https://myaccount.google.com/apppasswords
```

Optional but **HIGHLY RECOMMENDED** (adds phone call):
```bash
# Twilio - FREE $15 trial: https://www.twilio.com/try-twilio
TWILIO_SID="ACxxxxxxxxxxxxx"
TWILIO_TOKEN="your_auth_token"
TWILIO_FROM="+1234567890"
TWILIO_TO="+34XXXXXXXXX"      # Your Spanish phone
ENABLE_CALL="true"
```

### 3. Start Monitoring
```bash
./monitor-cita.sh start
```

That's it! 🎉

## 📱 What Happens Next

Every 30 minutes, the script checks for appointments. When one is found:

1. ✅ **Email sent** - Check your inbox
2. ✅ **Phone rings** (if Twilio configured) - Answer it!
3. ✅ **Browser stays open** at booking page
4. ✅ **Monitoring stops** - No duplicate bookings

### Complete Booking NOW
```bash
# Open VNC browser in your web browser:
http://localhost:8080/vnc.html

# Firefox will be on the booking page
# Complete the booking within 5-10 minutes!
```

## 🔧 Default Settings (Change in .env)

```bash
PROVINCIA="Barcelona"
OFICINA="99"           # 99 = Any office (change to specific: 16 = Rambla Guipuscoa)
TRAMITE="4010"         # 4010 = Fingerprints after visa approval
CHECK_INTERVAL="30"    # Check every 30 minutes
```

## 📚 More Options

- **All tramite types**: See `.env.example` lines 15-52
- **All Barcelona oficinas**: See `.env.example` lines 57-110
- **Detailed docs**: Read `CITA_README.md`

## 🛠️ Commands

```bash
./monitor-cita.sh start   # Start checking
./monitor-cita.sh status  # Is it running?
./monitor-cita.sh logs    # View recent activity
./monitor-cita.sh stop    # Stop checking
```

## ❓ Common Issues

### Gmail "Authentication Failed"
- Enable 2FA: https://myaccount.google.com/security
- Create App Password: https://myaccount.google.com/apppasswords
- Use app password in SMTP_PASS

### Twilio Not Working
- Verify your phone number in Twilio console
- Check you have trial credit ($15 free)
- Use international format: +34XXXXXXXXX

### Monitor Not Starting
```bash
# Check if .env exists
ls -la /workspace/cita-checker/.env

# Check for syntax errors
cat /workspace/cita-checker/.env | grep -v "^#" | grep -v "^$"
```

## 🎓 Pro Tips

1. **Use Twilio phone calls** - Most reliable notification (wakes you up!)
2. **Specific office preferred** - Change `OFICINA="16"` for Rambla Guipuscoa
3. **Check logs regularly** - `./monitor-cita.sh logs` shows activity
4. **Edit scripts live** - Changes to `cita-checker/` files don't need rebuild
5. **Act fast** - Appointments disappear in 5-10 minutes

## 📞 Need Help?

- Read full docs: `CITA_README.md`
- Check logs: `./monitor-cita.sh logs`
- View all options: `.env.example`
