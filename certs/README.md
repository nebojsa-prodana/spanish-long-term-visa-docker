# Certificate Directory

Place your Spanish digital certificate files (.p12 or .pfx) in this directory.

## ⚠️ SECURITY WARNING ⚠️

**NEVER commit actual certificate files to version control!**

Certificate files are ignored by .gitignore but always double-check before pushing:
- *.p12
- *.pfx  
- *.crt
- *.cer
- *.pem

## Example:
```bash
cp /path/to/your-certificate.p12 certs/
# Then run: make run
```

Your certificates will be automatically imported into the containerized Firefox during startup.