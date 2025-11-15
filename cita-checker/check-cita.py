#!/usr/bin/env python3
"""
Cita checker using Selenium for browser automation.
Checks for available police appointments and notifies via email.
"""

import os
import sys
import time
import logging
import argparse
import smtplib
from datetime import datetime
from pathlib import Path
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait, Select
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.common.exceptions import TimeoutException, NoSuchElementException
    from selenium.webdriver.firefox.options import Options
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False
    print("ERROR: Selenium not installed. Run: pip3 install selenium")
    sys.exit(1)

# Configuration
CITA_URL = "https://icp.administracionelectronica.gob.es/icpplustieb"
SCREENSHOT_DIR = Path("/tmp/cita-screenshots")
LOG_FILE = Path("/tmp/cita-checker-selenium.log")

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class CitaChecker:
    """Check for available appointments at Spanish police office."""
    
    def __init__(self, provincia, oficina, tramite, use_clave=True):
        """
        Initialize the cita checker.
        
        Args:
            provincia: Province name
            oficina: Police office name
            tramite: Type of appointment (e.g., "POLICIA-TOMA DE HUELLAS")
            use_clave: Whether to use Cl@ve (digital certificate) authentication
        """
        self.provincia = provincia
        self.oficina = oficina
        self.tramite = tramite
        self.use_clave = use_clave
        self.driver = None
        
        # Create screenshot directory
        SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    
    def setup_firefox(self):
        """Setup Firefox with the existing profile that has certificates."""
        logger.info("Setting up Firefox with existing profile...")
        
        options = Options()
        # Use the existing Firefox profile that has certificates
        profile_path = "/home/autofirma/.mozilla/firefox/profile.default"
        if os.path.exists(profile_path):
            options.add_argument(f"-profile")
            options.add_argument(profile_path)
            logger.info(f"Using Firefox profile: {profile_path}")
        else:
            logger.warning(f"Profile not found: {profile_path}")
        
        # Set display
        options.add_argument("--display=:0")
        
        # Create Firefox driver
        try:
            # Use the existing Firefox installation
            firefox_binary = "/opt/firefox/firefox"
            if os.path.exists(firefox_binary):
                options.binary_location = firefox_binary
                logger.info(f"Using Firefox binary: {firefox_binary}")
            
            self.driver = webdriver.Firefox(options=options)
            self.driver.set_page_load_timeout(30)
            logger.info("✓ Firefox driver initialized")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize Firefox driver: {e}")
            logger.error("Make sure geckodriver is installed and in PATH")
            return False
    
    def take_screenshot(self, name):
        """Take a screenshot of the current page."""
        if self.driver:
            timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            filepath = SCREENSHOT_DIR / f"{name}-{timestamp}.png"
            try:
                self.driver.save_screenshot(str(filepath))
                logger.info(f"Screenshot saved: {filepath}")
            except Exception as e:
                logger.error(f"Failed to save screenshot: {e}")
    
    def wait_and_click(self, by, value, timeout=10):
        """Wait for element and click it."""
        try:
            element = WebDriverWait(self.driver, timeout).until(
                EC.element_to_be_clickable((by, value))
            )
            element.click()
            logger.info(f"Clicked element: {value}")
            return True
        except TimeoutException:
            logger.warning(f"Timeout waiting for element: {value}")
            return False
        except Exception as e:
            logger.error(f"Error clicking element {value}: {e}")
            return False
    
    def select_dropdown_option(self, select_id, option_text):
        """Select an option from a dropdown by visible text."""
        try:
            select_element = WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.ID, select_id))
            )
            select = Select(select_element)
            select.select_by_visible_text(option_text)
            logger.info(f"Selected '{option_text}' in dropdown '{select_id}'")
            return True
        except Exception as e:
            logger.error(f"Error selecting option in dropdown {select_id}: {e}")
            return False
    
    def authenticate_with_clave(self):
        """Authenticate using Cl@ve (digital certificate)."""
        logger.info("Attempting to authenticate with Cl@ve...")
        
        try:
            # Look for Cl@ve button or link
            # Note: The exact selectors will need to be adjusted based on the actual website
            clave_button_selectors = [
                (By.LINK_TEXT, "Cl@ve"),
                (By.PARTIAL_LINK_TEXT, "Certificado"),
                (By.PARTIAL_LINK_TEXT, "Cl@ve"),
                (By.ID, "clave-button"),
                (By.CLASS_NAME, "clave-auth")
            ]
            
            for by, value in clave_button_selectors:
                try:
                    element = self.driver.find_element(by, value)
                    element.click()
                    logger.info(f"Clicked authentication option: {value}")
                    time.sleep(2)
                    self.take_screenshot("authentication")
                    return True
                except NoSuchElementException:
                    continue
            
            logger.warning("Could not find Cl@ve authentication button")
            self.take_screenshot("authentication-not-found")
            return False
            
        except Exception as e:
            logger.error(f"Error during authentication: {e}")
            self.take_screenshot("authentication-error")
            return False
    
    def navigate_to_appointment_form(self):
        """Navigate through the website to the appointment form."""
        logger.info(f"Navigating to {CITA_URL}...")
        
        try:
            # Load the main page
            self.driver.get(CITA_URL)
            time.sleep(3)
            self.take_screenshot("homepage")
            
            # Log current URL and title
            logger.info(f"Current URL: {self.driver.current_url}")
            logger.info(f"Page title: {self.driver.title}")
            
            # Authenticate if required
            if self.use_clave:
                self.authenticate_with_clave()
                time.sleep(3)
            
            # This is where you would navigate through the form
            # The exact steps depend on the website structure
            # Common steps might include:
            # 1. Select provincia
            # 2. Select oficina
            # 3. Select tipo de tramite
            # 4. Check for available appointments
            
            logger.info("Form navigation would continue here...")
            logger.info("Note: Specific form interactions need to be implemented based on website structure")
            
            return True
            
        except Exception as e:
            logger.error(f"Error navigating to appointment form: {e}")
            self.take_screenshot("navigation-error")
            return False
    
    def check_availability(self):
        """
        Check if appointments are available.
        
        Returns:
            str: "AVAILABLE", "NOT_AVAILABLE", or "ERROR"
        """
        logger.info("Checking for cita availability...")
        
        try:
            # Navigate to the form
            if not self.navigate_to_appointment_form():
                return "ERROR"
            
            # Look for availability indicators
            # These selectors are examples and need to be adjusted based on actual website
            availability_indicators = {
                "available": [
                    "hay citas disponibles",
                    "citas disponibles",
                    "disponible",
                    "appointment available"
                ],
                "not_available": [
                    "no hay citas disponibles",
                    "sin citas",
                    "no disponible",
                    "no appointments"
                ]
            }
            
            # Get page text
            page_text = self.driver.find_element(By.TAG_NAME, "body").text.lower()
            logger.info(f"Page text preview: {page_text[:200]}...")
            
            # Check for availability
            for phrase in availability_indicators["available"]:
                if phrase.lower() in page_text:
                    logger.info(f"✓ Found availability indicator: '{phrase}'")
                    self.take_screenshot("cita-available")
                    return "AVAILABLE"
            
            for phrase in availability_indicators["not_available"]:
                if phrase.lower() in page_text:
                    logger.info(f"○ Found no-availability indicator: '{phrase}'")
                    self.take_screenshot("cita-not-available")
                    return "NOT_AVAILABLE"
            
            # If we can't determine, take a screenshot for manual review
            logger.warning("⚠ Could not determine availability automatically")
            self.take_screenshot("availability-unknown")
            return "ERROR"
            
        except Exception as e:
            logger.error(f"Error checking availability: {e}")
            self.take_screenshot("check-error")
            return "ERROR"
    
    def run(self):
        """Run the complete check process."""
        logger.info("="*60)
        logger.info("Starting cita availability check")
        logger.info(f"Provincia: {self.provincia}")
        logger.info(f"Oficina: {self.oficina}")
        logger.info(f"Tramite: {self.tramite}")
        logger.info(f"Use Cl@ve: {self.use_clave}")
        logger.info("="*60)
        
        try:
            # Setup browser
            if not self.setup_firefox():
                logger.error("Failed to setup Firefox")
                return "ERROR"
            
            # Check availability
            result = self.check_availability()
            
            logger.info(f"Check result: {result}")
            return result
            
        finally:
            # Cleanup
            if self.driver:
                logger.info("Closing browser...")
                self.driver.quit()


def main():
    """Main entry point."""
    
    # Check if Selenium is available
    if not SELENIUM_AVAILABLE:
        logger.error("Selenium is not installed!")
        logger.error("Please install: pip install selenium")
        logger.error("And install geckodriver: https://github.com/mozilla/geckodriver/releases")
        sys.exit(1)
    
    # Parse arguments
    parser = argparse.ArgumentParser(
        description="Check for available appointments at Spanish police office"
    )
    parser.add_argument(
        "-p", "--provincia",
        required=True,
        help="Province name (e.g., 'Barcelona', 'Madrid')"
    )
    parser.add_argument(
        "-o", "--oficina",
        required=True,
        help="Police office name"
    )
    parser.add_argument(
        "-t", "--tramite",
        required=True,
        help="Type of appointment (e.g., 'POLICIA-TOMA DE HUELLAS')"
    )
    parser.add_argument(
        "--no-clave",
        action="store_true",
        help="Don't use Cl@ve authentication"
    )
    
    args = parser.parse_args()
    
    # Create checker
    checker = CitaChecker(
        provincia=args.provincia,
        oficina=args.oficina,
        tramite=args.tramite,
        use_clave=not args.no_clave
    )
    
    # Run check
    result = checker.run()
    
    # Exit with appropriate code
    if result == "AVAILABLE":
        sys.exit(0)  # Success - cita available
    elif result == "NOT_AVAILABLE":
        sys.exit(1)  # No cita available
    else:
        sys.exit(2)  # Error or manual check required


if __name__ == "__main__":
    main()
