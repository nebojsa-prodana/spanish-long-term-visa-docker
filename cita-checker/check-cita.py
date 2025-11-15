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
import random
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
CITA_URL = "https://icp.administracionelectronica.gob.es/icpplus/index.html"
SCREENSHOT_DIR = Path(f"/certs/cita-screenshots/{datetime.now().strftime('%Y%m%d-%H%M%S')}")
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

# Realistic User-Agent strings to rotate through (avoid detection)
# IMPORTANT: Only Firefox User-Agents since we're actually running Firefox 52 ESR
# Mixing Chrome/Safari UAs with Firefox's navigator object would create detectable inconsistencies
USER_AGENTS = [
    # Firefox 52 ESR on various platforms (matching our actual Firefox version)
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:52.0) Gecko/20100101 Firefox/52.0",
    "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:52.0) Gecko/20100101 Firefox/52.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0",
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.12; rv:52.0) Gecko/20100101 Firefox/52.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:52.0) Gecko/20100101 Firefox/52.0",
]


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
        
        # Set DISPLAY environment variable for X server
        os.environ['DISPLAY'] = ':0'
        logger.info("Set DISPLAY=:0 for X server")
        
        # Remove profile lock if it exists (from previous Firefox sessions)
        profile_path = "/home/autofirma/.mozilla/firefox/profile.default"
        lock_file = os.path.join(profile_path, ".parentlock")
        lock_symlink = os.path.join(profile_path, "lock")
        
        if os.path.exists(lock_file):
            os.remove(lock_file)
            logger.info("Removed .parentlock file")
        if os.path.exists(lock_symlink):  # lexists checks symlinks even if target doesn't exist
            os.remove(lock_symlink)
            logger.info("Removed lock symlink")
        
        # Use the existing Firefox profile that has certificates
        from selenium.webdriver.firefox.options import Options as FirefoxOptions
        from selenium.webdriver.firefox.firefox_profile import FirefoxProfile
        
        # Randomly select a User-Agent to avoid fingerprinting/detection
        user_agent = random.choice(USER_AGENTS)
        logger.info(f"Selected User-Agent: {user_agent}")
        
        options = FirefoxOptions()
        # Start Firefox in private browsing to avoid sticky cookies hitting load-balancers
        options.set_preference("browser.privatebrowsing.autostart", True)
        logger.info("Configured Firefox to start in private browsing mode")
        
        # Set randomized User-Agent
        options.set_preference("general.useragent.override", user_agent)
        
        # Try using FirefoxProfile object instead of command-line argument
        # This might work better with old Firefox + Selenium
        if os.path.exists(profile_path):
            profile = FirefoxProfile(profile_path)
            logger.info(f"Using Firefox profile: {profile_path}")
            
            # Disable problematic features that cause crashes in old Firefox
            profile.set_preference("browser.tabs.remote.autostart", False)
            profile.set_preference("browser.tabs.remote.autostart.2", False)
            profile.set_preference("extensions.e10sBlocksEnabling", True)
            profile.set_preference("browser.tabs.remote.force-enable", False)
            profile.set_preference("marionette.port", 2828)
            profile.set_preference("marionette.enabled", True)
            logger.info("Disabled multi-process mode (e10s) to prevent crashes")
            
            # Accept insecure certificates (Spanish government site has SSL issues)
            profile.set_preference("webdriver_accept_untrusted_certs", True)
            profile.set_preference("webdriver_assume_untrusted_issuer", True)
            profile.accept_untrusted_certs = True
            logger.info("Configured to accept insecure SSL certificates")
            
            # Configure automatic certificate selection
            # This tells Firefox to automatically select a certificate when prompted
            profile.set_preference("security.default_personal_cert", "Select Automatically")
            logger.info("Configured to auto-select certificate")

            # Privacy preferences to reduce tracking/cookies that may trip load-balancers
            # Clear cookies on shutdown and block third-party cookies
            profile.set_preference("network.cookie.lifetimePolicy", 2)  # 2 = session-only
            profile.set_preference("network.cookie.thirdparty.sessionOnly", True)
            profile.set_preference("network.cookie.cookieBehavior", 1)  # 1 = block third-party cookies
            logger.info("Configured cookie/privacy preferences for private session")
            
            # Apply the same User-Agent to the profile (for consistency)
            profile.set_preference("general.useragent.override", user_agent)
            
            # HTTP Headers - make them common to blend in (based on AmIUnique findings)
            # Accept header: Use more common modern Firefox accept header
            profile.set_preference("network.http.accept.default", "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8")
            
            # Accept-Language: Use Spanish as primary to match the target website
            # Randomize slightly but keep realistic for Spain
            lang_variants = [
                "es-ES,es;q=0.9",  # Most common for Spanish users
                "es-ES,es;q=0.8,en-US;q=0.5,en;q=0.3",  # Spanish user with some English
                "es,es-ES;q=0.9,en;q=0.7",  # Alternative Spanish priority
            ]
            selected_lang = random.choice(lang_variants)
            profile.set_preference("intl.accept_languages", selected_lang)
            
            # Accept-Encoding: Common encoding support (gzip, deflate, br)
            # Firefox 52 supports these
            profile.set_preference("network.http.accept-encoding", "gzip, deflate, br")
            
            # DNT (Do Not Track): Most users don't set this, so disable it to be more common
            profile.set_preference("privacy.donottrackheader.enabled", False)
            
            # Upgrade-Insecure-Requests: Set to 1 (standard for modern browsers)
            # This is automatically sent by Firefox 52+
            
            # Disable WebRTC to prevent IP leaks
            profile.set_preference("media.peerconnection.enabled", False)
            
            # Disable geolocation
            profile.set_preference("geo.enabled", False)
            
            # Disable WebGL (can be used for fingerprinting)
            profile.set_preference("webgl.disabled", True)
            
            # Disable battery API (fingerprinting vector)
            profile.set_preference("dom.battery.enabled", False)
            
            # Disable canvas fingerprinting
            # Note: This might break some sites, but reduces fingerprinting surface
            profile.set_preference("privacy.resistFingerprinting", True)
            
            logger.info(f"Applied anti-fingerprinting: lang={selected_lang}, headers=normalized, resistFingerprinting=true")
        else:
            profile = None
            logger.warning(f"Profile not found: {profile_path}")
        
        # Create Firefox driver
        try:
            # Use the existing Firefox installation
            firefox_binary = "/opt/firefox/firefox"
            options.binary_location = firefox_binary
            logger.info(f"Using Firefox binary: {firefox_binary}")
            
            # Selenium 3.14.1 + GeckoDriver 0.19.1 + Firefox 52 ESR
            # Use firefox_profile parameter instead of options for better compatibility
            self.driver = webdriver.Firefox(
                firefox_profile=profile,
                firefox_binary=firefox_binary,
                options=options,
                executable_path="/usr/local/bin/geckodriver",
                service_log_path="/tmp/geckodriver.log",
                timeout=60  # Increase timeout for slow startup
            )
            
            # Set timeouts for page loads and implicit waits
            self.driver.set_page_load_timeout(120)  # 2 minutes for slow pages
            self.driver.implicitly_wait(10)  # Wait up to 10 seconds for elements
            
            # Maximize window to ensure all elements are visible
            try:
                self.driver.maximize_window()
                logger.info("✓ Window maximized")
            except Exception as e:
                logger.warning(f"Could not maximize window: {e}")

            # Immediately clear cookies to ensure a pristine session inside the private window
            try:
                self.driver.delete_all_cookies()
                logger.info("Cleared all cookies after browser start to avoid sticky session issues")
            except Exception as e:
                logger.warning(f"Could not clear cookies: {e}")
            # Also clear local/session storage to remove any sticky state
            try:
                self.driver.execute_script("window.localStorage.clear(); window.sessionStorage.clear();")
                logger.info("Cleared localStorage and sessionStorage")
            except Exception as e:
                logger.warning(f"Could not clear local/session storage: {e}")
            
            logger.info("✓ Firefox driver initialized with timeouts")
            
            return True
        except Exception:
            logger.exception("Failed to initialize Firefox driver")
            logger.error("Check Firefox and GeckoDriver compatibility")
            
            # Try to read geckodriver log for more details
            try:
                with open("/tmp/geckodriver.log", "r") as f:
                    log_content = f.read()
                    if log_content:
                        logger.error("GeckoDriver log output:")
                        logger.error(log_content[-2000:])  # Last 2000 chars
            except Exception:
                pass
            
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
    
    def wait_and_click(self, by, selector, timeout=10, script_click=True):
        """Wait for element and click it."""
        try:
            element = WebDriverWait(self.driver, timeout).until(
                EC.element_to_be_clickable((by, selector))
            )
            
            # Scroll element into view before clicking
            try:
                self.driver.execute_script("arguments[0].scrollIntoView(true);", element)
                time.sleep(0.5)  # Brief pause after scroll
                logger.info(
                    f"Scrolled element into view: tag={element.tag_name}, "
                    f"id={element.get_attribute('id')}, "
                    f"class={element.get_attribute('class')}, "
                    f"text={element.text.strip()[:80]!r}, "
                    f"selector={selector}"
                )
            except Exception:
                logger.exception("Could not scroll element into view: : tag={element.tag_name}, "
                    f"id={element.get_attribute('id')}, "
                    f"class={element.get_attribute('class')}, "
                    f"text={element.text.strip()[:80]!r}, "
                    f"selector={selector}"
                )
            if script_click:
                self.driver.execute_script("arguments[0].click();", element)
            else:
                element.click()
            logger.info(f"Clicked element: : tag={element.tag_name}, "
                f"id={element.get_attribute('id')}, "
                f"class={element.get_attribute('class')}, "
                f"text={element.text.strip()[:80]!r}, "
                f"selector={selector}"
            )
            return True
        except TimeoutException:
            logger.warning(f"Timeout waiting for element via selector: {selector}")
            return False
        except Exception:
            logger.exception(f"Error clicking element via selector {selector}")
            return False

    def wait_for_ready_state(self, timeout=120):
        """Wait until document.readyState == 'complete'. Returns True if ready, False on timeout."""
        try:
            WebDriverWait(self.driver, timeout).until(
                lambda d: d.execute_script("return document.readyState") == "complete"
            )
            logger.info("✓ document.readyState == 'complete'")
            return True
        except TimeoutException:
            logger.warning(f"Timeout waiting for document.readyState to be 'complete' (timeout={timeout}s)")
            return False
        except Exception as e:
            logger.warning(f"Error while waiting for readyState: {e}")
            return False
    
    # def select_dropdown_option(self, select_id, option_text):
    #     """Select an option from a dropdown by visible text."""
    #     try:
    #         select_element = WebDriverWait(self.driver, 10).until(
    #             EC.presence_of_element_located((By.ID, select_id))
    #         )
    #         select = Select(select_element)
    #         select.select_by_visible_text(option_text)
    #         logger.info(f"Selected '{option_text}' in dropdown '{select_id}'")
    #         return True
    #     except Exception as e:
    #         logger.error(f"Error selecting option in dropdown {select_id}: {e}")
    #         return False

    
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
    
    def select_provincia(self):
        """Select provincia from dropdown."""
        logger.info(f"Selecting provincia: {self.provincia}")
        
        try:
            # Use explicit XPath selectors per user guidance
            provincia_dropdown = WebDriverWait(self.driver, 30).until(
                EC.presence_of_element_located((By.XPATH, '//*[@id="form"]'))
            )
            
            # Scroll into view
            try:
                self.driver.execute_script("arguments[0].scrollIntoView(true);", provincia_dropdown)
                time.sleep(0.5)
                logger.info("Scrolled provincia dropdown into view")
            except Exception as e:
                logger.warning(f"Could not scroll provincia dropdown: {e}")
            
            select = Select(provincia_dropdown)
            select.select_by_visible_text(self.provincia)
            logger.info(f"✓ Selected provincia: {self.provincia}")
            time.sleep(2)  # Increased delay to mimic human behavior
            self.take_screenshot("provincia-selected")

            # Wait a bit before clicking (human-like delay)
            logger.info("Pausing before clicking Aceptar (mimicking human behavior)...")
            time.sleep(2)
            
            # Click Aceptar via XPath
            if not self.wait_and_click(By.ID, "btnAceptar", timeout=30):
                logger.warning("Could not click Aceptar after provincia")

            # Wait for redirect to finish (up to 2 minutes)
            self.wait_for_ready_state(timeout=120)
            return True
            
        except Exception as e:
            logger.error(f"Error selecting provincia: {e}")
            self.take_screenshot("provincia-error")
            return False
    
    def select_oficina(self):
        """Select the oficina (office) from dropdown."""
        try:
            logger.info(f"Selecting oficina: {self.oficina}")
            
            # Wait for oficina dropdown to be present - use XPath as provided
            oficina_dropdown = WebDriverWait(self.driver, 30).until(
                EC.presence_of_element_located((By.XPATH, '//*[@id="sede"]'))
            )
            
            # Scroll into view
            try:
                self.driver.execute_script("arguments[0].scrollIntoView(true);", oficina_dropdown)
                time.sleep(0.5)
                logger.info("Scrolled oficina dropdown into view")
            except Exception as e:
                logger.warning(f"Could not scroll oficina dropdown: {e}")
            
            select = Select(oficina_dropdown)

            logger.info(f"Selecting oficina by value: {self.oficina}")
            select.select_by_value(self.oficina)
            logger.info(f"✓ Selected oficina by value: {self.oficina}")
            
            time.sleep(2)  # Increased delay to mimic human behavior
            self.take_screenshot("oficina-selected")
            return True
            
        except Exception as e:
            logger.error(f"Error selecting oficina: {e}")
            self.take_screenshot("oficina-error")
            return False
    
    def select_tramite(self):
        """Select the tramite (procedure type) from dropdown."""
        try:
            logger.info(f"Selecting tramite: {self.tramite}")
            
            # Wait for tramite dropdown to be present - use XPath as provided
            tramite_dropdown = WebDriverWait(self.driver, 30).until(
                EC.presence_of_element_located((By.XPATH, '//*[@id="tramiteGrupo[0]"]'))
            )
            
            # Scroll into view
            try:
                self.driver.execute_script("arguments[0].scrollIntoView(true);", tramite_dropdown)
                time.sleep(0.5)
                logger.info("Scrolled tramite dropdown into view")
            except Exception as e:
                logger.warning(f"Could not scroll tramite dropdown: {e}")
            
            select = Select(tramite_dropdown)
            select.select_by_value(self.tramite)
            logger.info(f"✓ Selected tramite: {self.tramite}")
            
            time.sleep(2)  # Increased delay to mimic human behavior
            self.take_screenshot("tramite-selected")
            
            # Wait for JavaScript to fully load and register onclick handlers
            # The button exists in DOM but its onclick handler might not be registered yet
            # Also helps avoid bot detection by not acting too quickly
            logger.info("Waiting for page JavaScript to initialize and mimicking human behavior...")
            time.sleep(5)  # Longer delay to avoid bot detection
            
            # Additional human-like delay before clicking
            logger.info("Pausing before clicking Aceptar (mimicking human behavior)...")
            time.sleep(3)

            current_url = self.driver.current_url
            logger.info(f"Current URL before clicking: {current_url}")
            
            # Click "Aceptar" using XPath and wait for redirect (up to 2 minutes)
            if not self.wait_and_click(By.ID, "btnAceptar", timeout=30, script_click=True):
                logger.warning("Could not click Aceptar after tramite selection")
            else:
                # # Give extra time for the JavaScript onclick handler to execute and submit the form
                # logger.info("Waiting for form submission to process...")
                # time.sleep(5)  # Longer pause to ensure JS completes before checking for redirect

                # if not self.wait_and_click(By.ID, "btnAceptar", timeout=30, script_click=True):
                #     logger.error("Could not click Aceptar after tramite selection")
                #     return False
                
                # time.sleep(5)  # Longer pause to ensure JS completes before checking for redirect

                # logger.info("Waiting for redirect to authentication/availability page (can take minutes)...")
                # current_url = self.driver.current_url
                # logger.info(f"Current URL before waiting: {current_url}")
                
                # The page might redirect, or it might just update with a warning/error
                # Wait for EITHER:
                # 1. URL to change (redirect happened)
                # 2. Warning div to appear (no citas message shown on same page)
                # 3. Cl@ve button to appear (authentication page loaded)
                
                page_changed = False
                time.sleep(3)  # Additional buffer for any quick updates
                
                try:
                    # Wait for either URL change OR warning div OR clave button
                    WebDriverWait(self.driver, 120).until(
                        lambda d: d.current_url != current_url or 
                                  len(d.find_elements(By.XPATH, '//*[@id="warning"]')) > 0 or
                                  len(d.find_elements(By.XPATH, '//*[@id="btnAccesoClave"]')) > 0
                    )
                    page_changed = True
                    logger.info(f"✓ Page changed/updated - URL: {self.driver.current_url}")
                except TimeoutException:
                    logger.warning("Timeout waiting for page change, continuing anyway...")
                
                # Wait for page to be fully loaded
                self.wait_for_ready_state(timeout=60)
                time.sleep(3)  # Extra buffer
                self.take_screenshot("after-tramite-aceptar")
            
            return True
            
        except Exception as e:
            logger.error(f"Error selecting tramite: {e}")
            self.take_screenshot("tramite-error")
            return False
    
    def navigate_to_appointment_form(self):
        """Navigate through the website to the appointment form."""
        logger.info(f"Navigating to {CITA_URL}...")
        
        try:
            # Load the main page
            self.driver.get(CITA_URL)
            
            # Wait for page load to complete using document.readyState
            logger.info("Waiting for homepage to fully load...")
            try:
                WebDriverWait(self.driver, 120).until(
                    lambda d: d.execute_script("return document.readyState") == "complete"
                )
                logger.info("✓ Homepage loaded (document.readyState = complete)")
                
                # Also wait for the provincia form to be present
                WebDriverWait(self.driver, 30).until(
                    EC.presence_of_element_located((By.TAG_NAME, "select"))
                )
                logger.info("✓ Provincia form found")
            except TimeoutException:
                logger.warning("Timeout waiting for homepage to load")
            
            time.sleep(2)  # Extra buffer for JavaScript
            self.take_screenshot("homepage")
            
            # Log current URL and title
            logger.info(f"Current URL: {self.driver.current_url}")
            logger.info(f"Page title: {self.driver.title}")
            
            # Step 1: Select provincia
            if not self.select_provincia():
                logger.error("Failed to select provincia")
                return False
            
            logger.info("Successfully navigated past provincia selection")
            
            # Step 2: Select oficina
            if not self.select_oficina():
                logger.error("Failed to select oficina")
                return False
            
            # Step 3: Select tramite
            if not self.select_tramite():
                logger.error("Failed to select tramite")
                return False
            
            logger.info("✓ All selections complete, ready to check availability")
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
            # Navigate to the form (provincia, oficina, tramite)
            if not self.navigate_to_appointment_form():
                return "ERROR"
            
            # Now we should be on a page where we need to click the Cl@ve/eIdentifier button
            # Wait for page to load (can take a few minutes according to user)
            # Also mimicking human behavior - a real user would look at the page before clicking
            logger.info("Waiting for authentication page to load (this can take a few minutes)...")
            time.sleep(15)  # Longer delay to mimic human reading the page
            self.take_screenshot("auth-page")
            
            # Try to find and click the eIdentifier/Cl@ve button
            # User said: button with onclick="JAVASCRIPT:selectedIdP('AFIRMA');idpRedirect.submit();"
            # containing span with text "Access eIdentifier"
            if self.use_clave:
                try:
                    logger.info("Looking for Cl@ve/eIdentifier authentication button...")
                    
                    # Try multiple strategies to find the button
                    # Strategy A: Cl@ve button (div with onclick)
                    try:
                        if self.wait_and_click(By.XPATH, '//*[@id="btnAccesoClave"]', timeout=30):
                            logger.info("✓ Clicked Cl@ve (btnAccesoClave)")
                            time.sleep(5)  # Longer delay after clicking to mimic human behavior
                            self.take_screenshot("after-clave")
                        else:
                            logger.info("Cl@ve button not found via XPath, trying eIdentifier XPath")
                    except Exception as e:
                        logger.warning(f"Error clicking Cl@ve XPath: {e}")

                    # Strategy B: eIdentifier - find the span and click its parent button
                    try:
                        # Provided XPath points at the span; get its parent button
                        span_elem = WebDriverWait(self.driver, 10).until(
                            EC.presence_of_element_located((By.XPATH, '/html/body/div/main/div[2]/div/div/div/article[2]/div[4]/button/span[1]'))
                        )
                        # parent button
                        parent_button = span_elem.find_element(By.XPATH, '..')
                        parent_button.click()
                        logger.info("✓ Clicked eIdentifier parent button")
                        time.sleep(5)  # Longer delay after clicking to mimic human behavior
                        self.take_screenshot("after-eidentifier")
                    except Exception as e:
                        logger.warning(f"Could not click eIdentifier button via provided XPath: {e}")
                    
                    # Wait for certificate prompt or next page
                    logger.info("Waiting for certificate prompt or availability page...")
                    time.sleep(10)
                    self.take_screenshot("final-page")
                    
                except Exception as e:
                    logger.warning(f"Error clicking authentication button: {e}, continuing...")
            
            # Now check for availability on the final page
            # According to user: if "En este momento no hay citas disponibles" appears = not available
            # Otherwise, if no error on page = available
            
            # Prefer checking the 'warning' div if present
            try:
                warning_div = WebDriverWait(self.driver, 10).until(
                    EC.presence_of_element_located((By.XPATH, '//*[@id="warning"]'))
                )
                warning_text = warning_div.text.lower()
                logger.info(f"Warning div text preview: {warning_text[:500]}...")
                if "en este momento no hay citas disponibles" in warning_text:
                    logger.info("○ Found 'no hay citas disponibles' message in #warning")
                    self.take_screenshot("cita-not-available")
                    return "NOT_AVAILABLE"
            except Exception:
                logger.info("No #warning div found or unable to read it; falling back to full page text")

            page_text = self.driver.find_element(By.TAG_NAME, "body").text.lower()
            logger.info(f"Final page text preview: {page_text[:500]}...")
            
            # Check for various error conditions first
            error_indicators = [
                "the requested url was rejected",
                "url was rejected",
                "error",
                "exception",
                "support id",
                "consult with your administrador",
                "go back"
            ]
            
            for error_indicator in error_indicators:
                if error_indicator in page_text:
                    logger.warning(f"⚠ Found error indicator: '{error_indicator}'")
                    self.take_screenshot("availability-error")
                    return "ERROR"
            
            # Check for "no citas disponibles" message
            if "en este momento no hay citas disponibles" in page_text:
                logger.info("○ Found 'no hay citas disponibles' message")
                self.take_screenshot("cita-not-available")
                return "NOT_AVAILABLE"
            
            # Only if we have positive indicators of availability, mark as AVAILABLE
            # Look for appointment-related keywords that suggest we're on the right page
            positive_indicators = [
                "solicitar cita",
                "seleccione fecha",
                "citas disponibles",
                "reservar cita",
                "calendario"
            ]
            
            has_positive_indicator = any(indicator in page_text for indicator in positive_indicators)
            
            if has_positive_indicator:
                logger.info("✓ Found positive availability indicators - cita may be AVAILABLE")
                self.take_screenshot("cita-available")
                return "AVAILABLE"
            
            # If we don't see clear positive or negative indicators, treat as ERROR
            logger.warning("⚠ Could not determine availability status - no clear indicators found")
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
        
        result = "ERROR"  # Initialize result for finally block
        
        try:
            # Setup browser
            if not self.setup_firefox():
                logger.error("Failed to setup Firefox")
                logger.error("CRITICAL: Cannot proceed without working browser")
                return "ERROR"
            
            # Verify driver is working
            if not self.driver:
                logger.error("CRITICAL: Driver is None after setup")
                return "ERROR"
            
            # Check availability
            result = self.check_availability()
            
            logger.info(f"Check result: {result}")
            
            # If cita is AVAILABLE, keep browser open for user to manually select
            if result == "AVAILABLE":
                logger.info("="*60)
                logger.info("🎉 CITA AVAILABLE! 🎉")
                logger.info("Browser will remain OPEN for you to select your appointment.")
                logger.info("Please complete the booking process manually.")
                logger.info("Press Ctrl+C when finished to close the browser.")
                logger.info("="*60)
                
                try:
                    # Keep the browser alive - wait indefinitely until user interrupts
                    while True:
                        time.sleep(60)  # Check every minute if process is still alive
                except KeyboardInterrupt:
                    logger.info("User interrupted - closing browser...")
                except Exception as e:
                    logger.error(f"Error while keeping browser open: {e}")
            
            return result
            
        except Exception as e:
            logger.error(f"CRITICAL: Unhandled exception in run(): {e}")
            import traceback
            logger.error(traceback.format_exc())
            return "ERROR"
            
        finally:
            # Cleanup - only close browser if NOT available or on error
            # The AVAILABLE case handles browser lifecycle above
            if self.driver and result != "AVAILABLE":
                try:
                    logger.info("Closing browser...")
                    self.driver.quit()
                except Exception as e:
                    logger.error(f"Error closing browser: {e}")

def main():
    """Main entry point."""
    
    try:
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
            logger.info("EXIT CODE: 0 (CITA AVAILABLE)")
            sys.exit(0)  # Success - cita available
        elif result == "NOT_AVAILABLE":
            logger.info("EXIT CODE: 1 (NO CITA)")
            sys.exit(1)  # No cita available
        else:
            logger.error("EXIT CODE: 2 (ERROR)")
            sys.exit(2)  # Error or manual check required
            
    except SystemExit:
        # Re-raise sys.exit() calls
        raise
    except Exception as e:
        logger.error(f"FATAL: Unhandled exception in main(): {e}")
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(2)


if __name__ == "__main__":
    main()
