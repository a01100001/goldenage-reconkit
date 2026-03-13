#!/usr/bin/env bash
# GoldenAge ReconKit — Installer for Kali Linux
# Usage: bash install.sh

RED='\033[0;31m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}"
echo "  ██████╗  █████╗ ██████╗ ███████╗ ██████╗ ███╗   ██╗"
echo "  ██╔════╝ ██╔══██╗██╔══██╗██╔════╝██╔═══██╗████╗  ██║"
echo "  ██║  ███╗███████║██████╔╝█████╗  ██║   ██║██╔██╗ ██║"
echo "  ╚██████╔╝██║  ██║██║  ██║███████╗╚██████╔╝██║ ╚████║"
echo "   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝"
echo -e "  ReconKit Installer${NC}"
echo ""

# ── Python deps ──────────────────────────────────────────────────────────────
echo -e "${CYAN}[*] Installing Python dependencies...${NC}"
pip install -r requirements.txt --break-system-packages --quiet

# ── Playwright browsers ───────────────────────────────────────────────────────
echo -e "${CYAN}[*] Installing Playwright Chromium (for browser screenshots)...${NC}"
python3 -m playwright install chromium 2>/dev/null && \
    echo -e "${GREEN}[✓] Playwright Chromium installed${NC}" || \
    echo -e "${YELLOW}[!] Playwright install failed — browser screenshots disabled${NC}"

# ── Kali tools check ─────────────────────────────────────────────────────────
echo -e "${CYAN}[*] Checking Kali tools...${NC}"
TOOLS=(nmap nikto sqlmap gobuster whatweb hydra feroxbuster)
MISSING=()
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        echo -e "  ${GREEN}[✓]${NC} $tool"
    else
        echo -e "  ${RED}[✗]${NC} $tool — NOT FOUND"
        MISSING+=("$tool")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}[!] Missing tools: ${MISSING[*]}${NC}"
    echo -e "${YELLOW}    Install with: sudo apt install ${MISSING[*]} -y${NC}"
fi

# ── Wordlists ─────────────────────────────────────────────────────────────────
if [ ! -f /usr/share/wordlists/rockyou.txt ]; then
    echo -e "${YELLOW}[!] rockyou.txt not found. Extracting...${NC}"
    sudo gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null || true
fi

# ── Permissions ───────────────────────────────────────────────────────────────
chmod +x main.py
mkdir -p output/{reports,screenshots,logs}

echo ""
echo -e "${GREEN}[✓] GoldenAge ReconKit installed successfully!${NC}"
echo ""
echo -e "  Run with: ${CYAN}python3 main.py${NC}"
echo ""
echo -e "  Optional — set OpenCTI integration:"
echo -e "  ${YELLOW}export OPENCTI_URL=https://your-opencti-instance${NC}"
echo -e "  ${YELLOW}export OPENCTI_TOKEN=your-api-token${NC}"
echo ""
echo -e "  Optional — set Rudder integration:"
echo -e "  ${YELLOW}export RUDDER_URL=https://your-rudder-server${NC}"
echo -e "  ${YELLOW}export RUDDER_TOKEN=your-api-token${NC}"
