
   ██████╗  ██████╗ ██╗     ██████╗ ███████╗███╗   ██╗ █████╗  ██████╗ ███████╗
  ██╔════╝ ██╔═══██╗██║     ██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔════╝ ██╔════╝
  ██║  ███╗██║   ██║██║     ██║  ██║█████╗  ██╔██╗ ██║███████║██║  ███╗█████╗
  ██║   ██║██║   ██║██║     ██║  ██║██╔══╝  ██║╚██╗██║██╔══██║██║   ██║██╔══╝
  ╚██████╔╝╚██████╔╝███████╗██████╔╝███████╗██║ ╚████║██║  ██║╚██████╔╝███████╗
   ╚═════╝  ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

  R E C O N K I T   —   Unified Penetration Testing Framework   v1.0.0
  GoldenAge Cybersecurity Consultancy  |  goldenage-consultancy.com
  CEH | CPent | CHFI | ECIH | CISSP | ISO 27001

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ⚠  LEGAL NOTICE
  ─────────────────────────────────────────────────────────────────────────────
  GoldenAge ReconKit is designed exclusively for authorized penetration testing.
  Running this tool against any system you do not own, or do not have explicit
  written authorization to test, is ILLEGAL and may result in criminal charges.

  By using this tool you confirm that:
    • You own the target system, OR have written authorization from its owner
    • You accept full legal responsibility for all actions performed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


TABLE OF CONTENTS
─────────────────
  1.  What Is ReconKit?
  2.  Features at a Glance
  3.  Integrated Tools
  4.  System Requirements
  5.  Installation — Step by Step
      5a. Kali Linux (recommended)
      5b. Ubuntu / Debian
      5c. macOS
      5d. Windows (WSL2)
  6.  Optional Integrations (OpenCTI, Rudder)
  7.  Running ReconKit — Full Walkthrough
      7a. Launching the tool
      7b. Authorization prompt
      7c. Setting a target
      7d. Choosing a scan profile
      7e. BurpSuite proxy option
      7f. Module toggle menu
      7g. Watching the scan run
  8.  Understanding the Output
      8a. Terminal summary table
      8b. HTML report
      8c. PDF report
      8d. Text log file
      8e. Screenshots
  9.  Scan Profiles Explained
  10. Module Reference
  11. Report Structure Explained
  12. Troubleshooting
  13. File Structure


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. WHAT IS RECONKIT?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ReconKit is a command-line penetration testing framework that ties together
10 industry-standard tools into a single interactive workflow. Instead of
running each tool manually and collecting output by hand, ReconKit:

  • Takes a single target (IP, domain, or URL)
  • Runs all selected tools in sequence against that target
  • Maps every finding to a CVSS 3.1 score with full context
  • Captures screenshots automatically (browser + terminal)
  • Generates three ready-to-deliver output files:
      - An interactive HTML report (dark-themed, filterable by severity)
      - A professional PDF report (suitable for client delivery)
      - A pretty text log (readable in any text editor on any OS)

It is built by GoldenAge Cybersecurity Consultancy and designed to fit into
real-world pentest engagements where time, consistency, and professional
deliverables matter.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. FEATURES AT A GLANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ⚡ 10 integrated tools          One target input launches them all
  📊 CVSS 3.1 scoring             Every finding scored, vectored, and explained
  💥 Impact analysis              What an attacker can actually do with it
  🔧 Remediation guidance         Concrete fix steps per finding
  🔗 Reference links              CVE, OWASP, NVD links per finding
  📸 Dual screenshots             Browser page capture + terminal output as PNG
  📄 HTML report                  Interactive, dark-themed, severity-filterable
  📄 PDF report                   Professional, client-ready, branded
  📋 Text log                     Pretty boxed log, readable in any text editor
  🔍 3 scan profiles              quick / full / stealth
  🔀 Module toggle                Turn individual tools on or off before scanning
  🛡  BurpSuite integration        Route all HTTP through Burp proxy
  🔗 OpenCTI integration          Threat intel enrichment (optional)
  🩹 Rudder.io integration        Patch compliance checking (optional)
  📁 Organised output             Reports, screenshots, and logs in separate dirs


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. INTEGRATED TOOLS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Tool            What It Does                              Max CVSS
  ──────────────────────────────────────────────────────────────────
  nmap            Port scan, service detection, NSE vulns    9.8
  whatweb         Web technology & CMS fingerprinting        5.3
  nikto           Web server vulnerability scanning          8.1
  gobuster        Directory & file brute-forcing             9.8
  feroxbuster     Recursive endpoint discovery               9.1
  sqlmap          SQL injection detection (all types)        9.8
  hydra           Credential brute-force guidance            Info
  burpsuite       HTTP traffic interception                  Info
  opencti         Threat intelligence enrichment (optional)  9.0
  rudder          Patch compliance checking (optional)       9.0


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. SYSTEM REQUIREMENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Python          3.9 or higher
  OS              Kali Linux (recommended), Ubuntu 22+, macOS, Windows WSL2
  RAM             Minimum 2 GB (4 GB recommended for full scans)
  Disk            500 MB free (for wordlists and output)
  Network         Active connection to the target

  Python libraries (installed automatically):
    rich          Terminal UI and progress display
    requests      HTTP client for OpenCTI / Rudder API calls
    reportlab     PDF report generation
    Pillow        Terminal output to PNG screenshots
    playwright    Browser screenshots (optional but recommended)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5. INSTALLATION — STEP BY STEP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

────────────────────────────────────────
5a. KALI LINUX (Recommended)
────────────────────────────────────────

Most required tools are already on Kali. You mainly need Python deps.

Step 1 — Extract the project

    unzip goldenage_reconkit.zip
    cd goldenage_reconkit

Step 2 — Run the installer

    bash install.sh

  The installer will:
    • Install Python libraries (rich, reportlab, Pillow, playwright, requests)
    • Install Playwright's Chromium browser for screenshots
    • Check every tool and report anything missing
    • Ensure rockyou.txt wordlist is extracted
    • Create the output/ directory structure

Step 3 — Install any missing tools reported by the installer

    sudo apt update
    sudo apt install feroxbuster gobuster hydra nikto whatweb nmap sqlmap -y

Step 4 — Verify and run

    python3 main.py


────────────────────────────────────────
5b. UBUNTU / DEBIAN
────────────────────────────────────────

Step 1 — Install system tools

    sudo apt update
    sudo apt install nmap nikto gobuster hydra whatweb sqlmap -y

Step 2 — Install Feroxbuster

    curl -sL https://raw.githubusercontent.com/epi052/feroxbuster/main/install-nix.sh \
      | bash -s $HOME/.local/bin

Step 3 — Install Python dependencies

    cd goldenage_reconkit
    pip install -r requirements.txt --break-system-packages

Step 4 — Install Playwright browser

    python3 -m playwright install chromium

Step 5 — Run

    python3 main.py


────────────────────────────────────────
5c. macOS
────────────────────────────────────────

Step 1 — Install Homebrew (if not already installed)

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

Step 2 — Install tools via Homebrew

    brew install nmap nikto gobuster hydra feroxbuster

Step 3 — Install sqlmap

    pip3 install sqlmap

Step 4 — Install whatweb

    gem install whatweb

Step 5 — Python deps

    cd goldenage_reconkit
    pip3 install -r requirements.txt

Step 6 — Playwright browser

    python3 -m playwright install chromium

Step 7 — Run

    python3 main.py

  Note: nmap SYN scans (-sS) require root on macOS.
  If using the stealth profile: sudo python3 main.py


────────────────────────────────────────
5d. WINDOWS (WSL2)
────────────────────────────────────────

ReconKit runs on Windows through WSL2. After the scan, HTML and PDF
reports open natively in your Windows browser and PDF reader.

Step 1 — Enable WSL2
  Open PowerShell as Administrator:

    wsl --install

  Restart when prompted.

Step 2 — Install Kali Linux
  Open Microsoft Store, search "Kali Linux", install it.
  Launch it and complete the initial username/password setup.

Step 3 — Follow the Kali Linux instructions above (Section 5a)

Step 4 — Access your reports from Windows Explorer
  Reports are written to:
    ~/goldenage_reconkit/output/reports/

  In Windows Explorer, navigate to:
    \\wsl$\kali-linux\home\<your-username>\goldenage_reconkit\output\reports\

  Double-click the .html file to open in your browser,
  or the .pdf file to open in your PDF reader.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
6. OPTIONAL INTEGRATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

These are completely optional. ReconKit works fine without them.

────────────────────────────────────────
OpenCTI — Threat Intelligence
────────────────────────────────────────

When configured, ReconKit queries your OpenCTI instance to check whether
the target IP or domain appears in any known threat actor campaigns,
malware indicators, or attack patterns. Findings are mapped to MITRE
ATT&CK kill chain phases and threat confidence scores.

    export OPENCTI_URL=https://your-opencti-instance.io
    export OPENCTI_TOKEN=your-api-token

To make permanent (survives terminal restarts):

    echo 'export OPENCTI_URL=https://your-opencti.io' >> ~/.bashrc
    echo 'export OPENCTI_TOKEN=your-token'            >> ~/.bashrc
    source ~/.bashrc

If not configured, the module logs an informational finding and the
scan continues. It will not crash or block other modules.

More info: https://docs.opencti.io/


────────────────────────────────────────
Rudder.io — Patch Compliance
────────────────────────────────────────

When configured, ReconKit queries Rudder for the target node and
retrieves its patch compliance score — showing exactly which services
are out of date and need patching.

    export RUDDER_URL=https://your-rudder-server
    export RUDDER_TOKEN=your-api-token

If not configured, same as OpenCTI — informational finding, no crash.

More info: https://www.rudder.io/


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
7. RUNNING RECONKIT — FULL WALKTHROUGH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    cd goldenage_reconkit
    python3 main.py


────────────────────────────────────────
7a. Launching the tool
────────────────────────────────────────

The terminal clears and the GoldenAge ASCII banner appears, followed by
the version number and contact info.


────────────────────────────────────────
7b. Authorization prompt
────────────────────────────────────────

A red legal disclaimer box appears. You must explicitly confirm:

    Do you confirm you have authorization to test the target? [y/N]: y

Typing 'n' or pressing Enter exits immediately.


────────────────────────────────────────
7c. Setting a target
────────────────────────────────────────

Accepted formats:

    IP address:    192.168.1.1
    IP range:      192.168.1.0/24    (nmap only)
    Domain:        example.com
    Subdomain:     admin.example.com
    Full URL:      https://example.com
    With port:     http://example.com:8080

    🎯 Enter target (IP, domain, or URL): 192.168.1.100


────────────────────────────────────────
7d. Choosing a scan profile
────────────────────────────────────────

    quick     Fast scan — top 100 ports, shallow directory crawl
    full      Full scan — all 65535 ports, deep recursive crawl
    stealth   Low-noise — slow timing, rate-limited, IDS-evasion

    Profile [quick/full/stealth] (default: full): full


────────────────────────────────────────
7e. BurpSuite proxy option
────────────────────────────────────────

Before answering yes, ensure BurpSuite is already running:
  1. Open BurpSuite Community Edition
  2. Go to Proxy > Options
  3. Confirm listener is on 127.0.0.1 port 8080 and running
  4. Set Intercept to OFF so requests are not held up

    Route HTTP traffic through BurpSuite proxy (127.0.0.1:8080)? [y/N]: y

When enabled, all HTTP requests from nikto, gobuster, feroxbuster,
sqlmap, and whatweb appear in Burp's HTTP History for manual review.


────────────────────────────────────────
7f. Module toggle menu
────────────────────────────────────────

    Customize which modules run? [y/N]:

Press N to run all modules (default).
Press Y to see the toggle table and disable specific tools:

  #   Module        Available   Enabled
  ──────────────────────────────────────
  1   nmap          ✓ Yes       ● ON
  2   whatweb       ✓ Yes       ● ON
  3   nikto         ✓ Yes       ● ON
  4   gobuster      ✓ Yes       ● ON
  5   feroxbuster   ✓ Yes       ● ON
  6   sqlmap        ✓ Yes       ● ON
  7   hydra         ✓ Yes       ● ON
  8   burpsuite     ✓ Yes       ● ON
  9   opencti       ✓ Yes       ● ON
  10  rudder        ✓ Yes       ● ON

  Toggle module #: 7        (turns hydra OFF)
  Toggle module #: done     (proceeds with current selection)


────────────────────────────────────────
7g. Watching the scan run
────────────────────────────────────────

Each module runs one at a time with a clear section header:

  ─────────────── Module 3/10: NIKTO ───────────────
    → nikto -h http://192.168.1.100 -Format txt
    📸 Screenshot saved: nikto_192.168.1.100_143022.png
    🖥  Terminal screenshot saved: nikto_output_0_143022.png
    ✓ Nikto complete — 7 finding(s)

When all modules finish, the terminal findings table appears immediately
followed by report generation.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
8. UNDERSTANDING THE OUTPUT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All output lands in the output/ directory:

  output/
  ├── reports/       HTML and PDF reports
  ├── screenshots/   Browser and terminal PNG images
  └── logs/          Pretty text logs and debug logs


────────────────────────────────────────
8a. Terminal summary table
────────────────────────────────────────

Immediately after the scan a table prints to the terminal showing all
findings sorted by severity (Critical first):

  #  | Severity  | CVSS | Tool       | Title
  ─────────────────────────────────────────────────────
  1  | Critical  | 9.8  | sqlmap     | UNION-based SQLi — Parameter: id
  2  | Critical  | 9.8  | gobuster   | .env File Exposed
  3  | High      | 8.8  | nmap       | SMB Service Detected
  ...


────────────────────────────────────────
8b. HTML report
────────────────────────────────────────

File: output/reports/goldenage_report_<target>_<timestamp>.html

Open in Chrome, Firefox, Safari, or Edge. No internet required.

Contents:
  • Header — target, date, overall risk badge, GoldenAge branding
  • Engagement details table
  • Severity breakdown card
  • Clickable filter bar — show only Critical / High / Medium / Low / Info
  • Finding cards, each containing:
      - Severity badge + CVSS score bar
      - Description
      - Impact (what an attacker can do)
      - Remediation (how to fix it)
      - CVSS 3.1 vector string
      - Reference links (CVE, OWASP, NVD, vendor advisories)
      - Embedded PNG screenshots inline
      - Expandable raw tool output section


────────────────────────────────────────
8c. PDF report
────────────────────────────────────────

File: output/reports/goldenage_report_<target>_<timestamp>.pdf

Professional dark-themed PDF for client delivery.
Opens in any PDF reader on any OS.

Contents:
  • Cover page with full engagement details and risk rating
  • Executive summary with severity table and risk description
  • Every finding with all fields (description, impact, remediation,
    CVSS, vector, references)
  • GoldenAge branding and confidentiality footer on every page


────────────────────────────────────────
8d. Text log file
────────────────────────────────────────

File: output/logs/reconkit_log_<target>_<timestamp>.txt

A fully self-contained plain text file readable anywhere:
  Windows: Notepad, Notepad++, VS Code
  macOS:   TextEdit, VS Code
  Linux:   cat, less, nano, gedit, any terminal pager

Contents:
  • ASCII banner with GoldenAge branding
  • Engagement details (target, profile, date, duration, risk)
  • Severity breakdown with visual bar chart (█░ style)
  • Module execution table — tool name, status (✓/✗), finding count,
    run duration, and any error notes
  • Every finding in a clearly bordered box with all fields
  • Raw tool output section at the bottom
  • Confidentiality footer


────────────────────────────────────────
8e. Screenshots
────────────────────────────────────────

Folder: output/screenshots/

  Browser screenshots (.png)
    Playwright (headless Chromium) captures the live web page at the
    moment each web-facing module runs. Full-page, 1280px wide.
    Requires Playwright to be installed (install.sh handles this).

  Terminal screenshots (.png)
    Pillow renders raw tool output as a PNG image — dark background,
    green monospace text, cyan header — like a real terminal window.
    These are embedded inside the HTML report next to each finding.

    Falls back to .txt format if Pillow is not installed.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
9. SCAN PROFILES EXPLAINED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Profile   nmap flags        gobuster    feroxbuster      nikto
  ─────────────────────────────────────────────────────────────────
  quick     -T4 -F --open     -t 20       --depth 2 -t 20  -maxtime 60s
  full      -T4 -A -p- --open -t 50       --depth 6 -t 50  unlimited
  stealth   -T2 -sS --open    -t 5 300ms  --depth 3 rate10 -maxtime 300s

  quick
    Scans only the top 100 most common ports. Shallow directory
    brute-force (2 levels deep). Nikto capped at 60 seconds.
    Expected scan time: 5–15 minutes.
    Use for: initial quick triage, time-limited assessments.

  full
    Scans all 65535 ports with full service/OS detection (-A flag).
    Deep recursive directory discovery (6 levels). No time limits.
    Expected scan time: 30–90 minutes depending on target.
    Use for: thorough assessments, final deliverable reports.

  stealth
    Uses nmap's slow timing (-T2) and SYN scan (requires root/sudo).
    Rate-limited directory scanning to avoid triggering IDS/WAF.
    Expected scan time: 45–120 minutes.
    Use for: testing detection controls, low-noise engagements.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
10. MODULE REFERENCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

nmap
  Runs a port scan with service version detection. Uses NSE (Nmap
  Scripting Engine) vuln and banner scripts to detect known CVEs
  automatically. Every open port is mapped to a severity and CVSS
  score using a built-in risk database covering FTP, Telnet, SSH,
  SMTP, SMB, RDP, MySQL, MSSQL, MongoDB, Redis, and more.

whatweb
  Fingerprints the web server and identifies the full technology stack:
  CMS type (WordPress, Joomla, Drupal), web server (Apache, nginx, IIS),
  programming language (PHP), and HTTP headers. Detects version exposure
  and flags known risky technology versions.

nikto
  Scans the web server for common misconfigurations, dangerous files,
  outdated software, missing security headers, XSS vectors, and HTTP
  method abuse. Maps OSVDB identifiers to findings where available.

gobuster
  Brute-forces directories and files using a wordlist. Checks for
  extensions: php, html, js, txt, bak, zip, tar, gz, json, xml, yml,
  env. Automatically flags high-risk paths: /admin, /.git, /.env,
  /phpmyadmin, /backup, /db, /swagger, /actuator, /config, and more.

feroxbuster
  Recursive endpoint discovery. Unlike gobuster which scans one level,
  feroxbuster follows each discovered directory and scans inside them
  too — surfacing hidden paths like /api/v2/internal or /backup/db that
  shallow scans miss. When BurpSuite proxy is enabled, every request
  is captured for manual inspection in Burp.

sqlmap
  Tests web forms and URL parameters for SQL injection. Detects all
  injection types: boolean-based blind, time-based blind, error-based,
  UNION query-based, and stacked queries. Crawls 2 levels to find
  injectable forms automatically. Uses a random user-agent string.

hydra
  Registers a detailed informational finding about credential testing
  and provides the correct syntax for manual Hydra runs against
  SSH, FTP, HTTP forms, and RDP. Example:

    hydra -L users.txt -P /usr/share/wordlists/rockyou.txt ssh://TARGET
    hydra -l admin -P passwords.txt ftp://TARGET
    hydra -l admin -P passwords.txt TARGET http-post-form \
      "/login:user=^USER^&pass=^PASS^:Invalid credentials"

burpsuite
  Checks whether BurpSuite is running on 127.0.0.1:8080 and reports
  proxy status. If active, confirms all HTTP modules route through it.
  If not running, provides setup instructions.

opencti (optional)
  Queries your OpenCTI platform for threat intelligence indicators
  matching the target. Returns threat actor associations, MITRE ATT&CK
  kill chain phases, confidence scores, and threat scores out of 100.
  Requires OPENCTI_URL and OPENCTI_TOKEN environment variables.

rudder (optional)
  Queries Rudder for the target node and retrieves its patch compliance
  percentage. Flags non-compliant rules and services needing patching
  with severity proportional to how far below 100% compliance the
  node sits. Requires RUDDER_URL and RUDDER_TOKEN environment variables.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
11. REPORT STRUCTURE EXPLAINED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Every finding in every report contains these fields:

  Field           What it means
  ──────────────────────────────────────────────────────────────────────────
  Title           Short name of the vulnerability or observation
  Tool            Which module discovered it
  Severity        Critical / High / Medium / Low / Info
  CVSS Score      Numeric score from 0.0 to 10.0 (CVSS v3.1 standard)
  CVSS Vector     e.g. AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H
                  Encodes attack vector, complexity, privileges, and impact
  Description     What was found and why it is a concern
  Impact          What an attacker can concretely accomplish with this finding
  Remediation     Step-by-step instructions to fix or mitigate the issue
  References      Links to CVE database, OWASP, NVD, vendor advisories
  Screenshot      PNG image of the browser page or terminal at time of finding
  Raw Output      The exact output from the tool that produced this finding
  Timestamp       When the finding was recorded during the scan

CVSS Score severity ranges (CVSS v3.1 standard):

  9.0 – 10.0   Critical   Patch or mitigate immediately
  7.0 – 8.9    High       Patch within days
  4.0 – 6.9    Medium     Patch within 30 days
  0.1 – 3.9    Low        Patch in next maintenance window
  0.0          Info       Informational — no immediate action required


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
12. TROUBLESHOOTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Problem:   ModuleNotFoundError: No module named 'rich'
Solution:  pip install rich --break-system-packages

Problem:   Tool 'feroxbuster' not found
Solution:  sudo apt install feroxbuster -y

Problem:   Playwright not installed — browser screenshots disabled
Solution:  pip install playwright --break-system-packages
           python3 -m playwright install chromium

Problem:   Nmap requires root for SYN scan (-sS, stealth profile)
Solution:  sudo python3 main.py
           Or avoid the stealth profile.

Problem:   PDF report not generated
Solution:  pip install reportlab --break-system-packages

Problem:   Terminal screenshots saved as .txt not .png
Solution:  pip install Pillow --break-system-packages

Problem:   OpenCTI / Rudder shows "Not configured"
Solution:  Set the environment variables described in Section 6.
           These are optional — the scan completes without them.

Problem:   rockyou.txt not found
Solution:  sudo gunzip /usr/share/wordlists/rockyou.txt.gz

Problem:   gobuster/feroxbuster wordlist not found
Solution:  sudo apt install seclists dirb -y
           The tool falls back to /usr/share/wordlists/dirb/common.txt

Problem:   BurpSuite proxy enabled but requests not appearing in Burp
Solution:  In BurpSuite: Proxy > Options > confirm listener on 127.0.0.1:8080
           In BurpSuite: Proxy > Intercept > set to "Intercept is off"
           (otherwise requests are paused waiting for manual forwarding)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
13. FILE STRUCTURE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  goldenage_reconkit/
  │
  ├── main.py                   Entry point — run this to start
  ├── config.py                 All settings: paths, profiles, wordlists
  ├── install.sh                One-click installer for Kali/Debian/Ubuntu
  ├── requirements.txt          Python library dependencies
  ├── README.md                 This file
  │
  ├── modules/
  │   ├── __init__.py           Imports all modules into ALL_MODULES list
  │   ├── base_module.py        Base class: Finding, BaseModule, run_command
  │   ├── nmap_module.py        Nmap port scan + NSE vuln detection
  │   ├── web_modules.py        Nikto, WhatWeb, SQLMap
  │   ├── recon_modules.py      Gobuster, Feroxbuster, Hydra, BurpSuite
  │   └── intel_modules.py      OpenCTI, Rudder.io
  │
  ├── reporter/
  │   ├── __init__.py           Imports all reporters
  │   ├── html_reporter.py      Generates the interactive HTML report
  │   ├── pdf_reporter.py       Generates the professional PDF report
  │   ├── log_reporter.py       Generates the pretty text log file
  │   └── screenshot.py         Browser (Playwright) + terminal (Pillow)
  │
  ├── utils/
  │   ├── __init__.py
  │   ├── banner.py             ASCII art banner displayed on launch
  │   └── logger.py             File-based debug logger
  │
  └── output/                   All generated output (created on first run)
      ├── reports/              HTML and PDF reports
      ├── screenshots/          Browser and terminal PNG images
      └── logs/                 Pretty text logs and debug logs


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GoldenAge Cybersecurity Consultancy
  info@goldenage-consultancy.com
  goldenage-consultancy.com

  CEH | CPent | CHFI | ECIH | CISSP | ISO 27001 Lead Auditor

  ⚠  This tool is for authorized use only.
     GoldenAge accepts no liability for unauthorized or illegal use.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
