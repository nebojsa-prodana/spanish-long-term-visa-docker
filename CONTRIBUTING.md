# Contributing

## Quick Start

```bash
git clone https://github.com/nebojsa-prodana/spanish-long-term-visa-docker.git
cd spanish-long-term-visa-docker
make build-and-run
```

Access at: http://localhost:8080/vnc.html

## How to Contribute

1. **Fork the repo**
2. **Create a branch**: `git checkout -b fix-something`
3. **Make changes and test**: `make build-and-run`
4. **Commit**: `git commit -m "Fix something"`
5. **Push and create PR**

## Testing

- Build and test: `make build-and-run`
- Test signing: https://sede.carm.es/cryptoApplet/ayuda/probarautofirma.html
- Run smoke tests: `/usr/local/bin/smoketest.sh` (inside container)

## Common Issues

Most problems are certificate-related. Check:
```bash
# Inside container
./troubleshoot.sh
```

## Code Style

- Use `set -euo pipefail` in shell scripts
- Clear commit messages
- Test your changes

## Questions?

Use GitHub Issues for bugs and questions.