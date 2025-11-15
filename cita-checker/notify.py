#!/usr/bin/env python3
"""
Multi-channel notification system for cita availability.
Supports: Email, Twilio SMS/Call, System beep, Log files
"""

import os
import sys
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

# Setup logging
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s')
logger = logging.getLogger(__name__)

VNC_URL = "http://localhost:8080/vnc.html"
CITA_URL = "https://icp.administracionelectronica.gob.es/icpplus/index.html"


def send_email(to_email, smtp_server, smtp_port, smtp_user, smtp_pass, provincia):
    """Send email notification."""
    try:
        subject = "🚨 CITA AVAILABLE NOW! - Act Immediately"
        
        body = f"""
<html>
<body style="font-family: Arial, sans-serif; padding: 20px; background-color: #f0f0f0;">
    <div style="background-color: #4CAF50; color: white; padding: 20px; text-align: center;">
        <h1>🎉 CITA AVAILABLE!</h1>
        <h2>Police Appointment Found in {provincia}</h2>
    </div>
    
    <div style="background-color: white; padding: 20px; margin-top: 20px; border-left: 5px solid #4CAF50;">
        <h2 style="color: #d32f2f;">⚠️ ACTION REQUIRED IMMEDIATELY</h2>
        <p style="font-size: 18px; color: #d32f2f; font-weight: bold;">
            Appointments fill up within MINUTES. Act NOW!
        </p>
        
        <h3>What to do:</h3>
        <ol style="font-size: 16px; line-height: 1.8;">
            <li><strong>Open VNC Browser:</strong> <a href="{VNC_URL}" style="color: #1976D2; font-size: 18px;">{VNC_URL}</a></li>
            <li><strong>Complete the booking</strong> - Firefox is already on the appointment page</li>
            <li><strong>Select your preferred date/time/location</strong></li>
            <li><strong>Submit immediately</strong></li>
        </ol>
        
        <div style="background-color: #fff3cd; padding: 15px; margin: 20px 0; border-left: 5px solid #ffc107;">
            <p style="margin: 0; font-size: 16px;">
                <strong>⏰ Time is critical!</strong><br>
                Detected at: <strong>{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</strong><br>
                These appointments are grabbed within 5-10 minutes of appearing.
            </p>
        </div>
        
        <h3>Backup Link:</h3>
        <p><a href="{CITA_URL}" style="color: #1976D2;">{CITA_URL}</a></p>
    </div>
    
    <div style="background-color: #f5f5f5; padding: 15px; margin-top: 20px; text-align: center; color: #666;">
        <p style="margin: 0; font-size: 14px;">
            This is an automated message from your cita monitoring system.<br>
            The monitoring has stopped automatically.
        </p>
    </div>
</body>
</html>
"""
        
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = smtp_user
        msg['To'] = to_email
        msg.attach(MIMEText(body, 'html'))
        
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.starttls()
            server.login(smtp_user, smtp_pass)
            server.send_message(msg)
        
        logger.info(f"✓ Email sent to {to_email}")
        return True
    except Exception as e:
        logger.error(f"✗ Email failed: {e}")
        return False


def send_twilio_sms(account_sid, auth_token, from_number, to_number, provincia):
    """Send SMS via Twilio."""
    try:
        from twilio.rest import Client
        
        client = Client(account_sid, auth_token)
        
        message = client.messages.create(
            body=f"🚨 CITA AVAILABLE in {provincia}! Open {VNC_URL} NOW! Appointments fill in minutes!",
            from_=from_number,
            to=to_number
        )
        
        logger.info(f"✓ SMS sent to {to_number} (SID: {message.sid})")
        return True
    except ImportError:
        logger.warning("⚠ Twilio not installed. Run: pip3 install twilio")
        return False
    except Exception as e:
        logger.error(f"✗ SMS failed: {e}")
        return False


def make_twilio_call(account_sid, auth_token, from_number, to_number, provincia):
    """Make phone call via Twilio with voice message."""
    try:
        from twilio.rest import Client
        
        client = Client(account_sid, auth_token)
        
        # TwiML response for voice message
        twiml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="alice" language="en-US" loop="3">
        Alert! Alert! Your Spanish police appointment is now available in {provincia}. 
        Open your V N C browser immediately at localhost port 8080 slash V N C dot html.
        Appointments fill up within minutes. Act now!
    </Say>
    <Pause length="2"/>
    <Say voice="alice" language="en-US">
        I repeat: Your cita is available. Check your V N C browser at localhost 8080 immediately.
    </Say>
</Response>"""
        
        call = client.calls.create(
            twiml=twiml,
            from_=from_number,
            to=to_number
        )
        
        logger.info(f"✓ Call initiated to {to_number} (SID: {call.sid})")
        return True
    except ImportError:
        logger.warning("⚠ Twilio not installed. Run: pip3 install twilio")
        return False
    except Exception as e:
        logger.error(f"✗ Call failed: {e}")
        return False


def system_alert():
    """Generate system beeps/alerts."""
    try:
        # Multiple beeps
        for _ in range(10):
            print('\a', end='', flush=True)
            import time
            time.sleep(0.5)
        
        logger.info("✓ System alert beeps sent")
        return True
    except Exception as e:
        logger.error(f"✗ System alert failed: {e}")
        return False


def write_urgent_file(provincia):
    """Write urgent notification file."""
    try:
        urgent_file = "/tmp/CITA_AVAILABLE_NOW.txt"
        with open(urgent_file, 'w') as f:
            f.write("="*60 + "\n")
            f.write("🚨 CITA AVAILABLE NOW! 🚨\n")
            f.write("="*60 + "\n")
            f.write(f"\nProvince: {provincia}\n")
            f.write(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"\nVNC Browser: {VNC_URL}\n")
            f.write(f"Website: {CITA_URL}\n")
            f.write("\n⚠️  ACT IMMEDIATELY - Appointments fill within minutes!\n")
            f.write("="*60 + "\n")
        
        os.chmod(urgent_file, 0o666)
        logger.info(f"✓ Urgent file created: {urgent_file}")
        return True
    except Exception as e:
        logger.error(f"✗ Urgent file failed: {e}")
        return False


def main():
    """Main notification dispatcher."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Send multi-channel cita notifications')
    parser.add_argument('-p', '--provincia', required=True, help='Province name')
    
    # Email (REQUIRED)
    parser.add_argument('--email-to', required=True, help='Recipient email (REQUIRED)')
    parser.add_argument('--smtp-server', required=True, help='SMTP server (REQUIRED)')
    parser.add_argument('--smtp-port', type=int, default=587, help='SMTP port')
    parser.add_argument('--smtp-user', required=True, help='SMTP username (REQUIRED)')
    parser.add_argument('--smtp-pass', required=True, help='SMTP password (REQUIRED)')
    
    # Twilio SMS/Call (OPTIONAL but recommended)
    parser.add_argument('--twilio-sid', help='Twilio Account SID')
    parser.add_argument('--twilio-token', help='Twilio Auth Token')
    parser.add_argument('--twilio-from', help='Twilio phone number (from)')
    parser.add_argument('--twilio-to', help='Your phone number (to)')
    parser.add_argument('--call', action='store_true', help='Make phone call (requires Twilio)')
    
    args = parser.parse_args()
    
    logger.info("="*60)
    logger.info("🚨 CITA FOUND - SENDING NOTIFICATIONS 🚨")
    logger.info("="*60)
    
    success_count = 0
    total_count = 0
    
    # 1. EMAIL (Required)
    total_count += 1
    if send_email(args.email_to, args.smtp_server, args.smtp_port, 
                  args.smtp_user, args.smtp_pass, args.provincia):
        success_count += 1
    
    # 2. TWILIO SMS (if configured)
    if args.twilio_sid and args.twilio_token and args.twilio_from and args.twilio_to:
        total_count += 1
        if send_twilio_sms(args.twilio_sid, args.twilio_token, 
                          args.twilio_from, args.twilio_to, args.provincia):
            success_count += 1
        
        # 3. PHONE CALL (if requested)
        if args.call:
            total_count += 1
            if make_twilio_call(args.twilio_sid, args.twilio_token,
                               args.twilio_from, args.twilio_to, args.provincia):
                success_count += 1
    
    # 4. SYSTEM ALERTS (always try)
    total_count += 1
    if system_alert():
        success_count += 1
    
    # 5. URGENT FILE (always try)
    total_count += 1
    if write_urgent_file(args.provincia):
        success_count += 1
    
    logger.info("="*60)
    logger.info(f"Notification summary: {success_count}/{total_count} successful")
    logger.info("="*60)
    
    if success_count == 0:
        logger.error("❌ ALL NOTIFICATIONS FAILED!")
        sys.exit(1)
    elif success_count < total_count:
        logger.warning(f"⚠ Some notifications failed ({total_count - success_count})")
        sys.exit(2)
    else:
        logger.info("✅ All notifications sent successfully")
        sys.exit(0)


if __name__ == "__main__":
    main()
