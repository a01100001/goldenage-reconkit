import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
SCREENSHOTS_DIR = os.path.join(OUTPUT_DIR, "screenshots")
REPORTS_DIR = os.path.join(OUTPUT_DIR, "reports")
LOGS_DIR = os.path.join(OUTPUT_DIR, "logs")

for d in [OUTPUT_DIR, SCREENSHOTS_DIR, REPORTS_DIR, LOGS_DIR]:
    os.makedirs(d, exist_ok=True)

TOOL_PATHS = {
    "nmap": "nmap",
    "nikto": "nikto",
    "sqlmap": "sqlmap",
    "gobuster": "gobuster",
    "whatweb": "whatweb",
    "hydra": "hydra",
    "feroxbuster": "feroxbuster",
}

SCAN_PROFILES = {
    "quick": {
        "description": "Fast scan - top ports, shallow crawl",
        "nmap_args": "-T4 -F --open",
        "gobuster_args": "-t 20",
        "feroxbuster_args": "--depth 2 -t 20",
        "nikto_args": "-maxtime 60",
    },
    "full": {
        "description": "Full scan - all ports, deep crawl",
        "nmap_args": "-T4 -A -p- --open",
        "gobuster_args": "-t 50",
        "feroxbuster_args": "--depth 6 -t 50",
        "nikto_args": "",
    },
    "stealth": {
        "description": "Stealth scan - low noise, slow",
        "nmap_args": "-T2 -sS --open",
        "gobuster_args": "-t 5 --delay 300ms",
        "feroxbuster_args": "--depth 3 -t 5 --rate-limit 10",
        "nikto_args": "-maxtime 300",
    }
}

BURP_PROXY = "http://127.0.0.1:8080"
OPENCTI_URL = os.getenv("OPENCTI_URL", "")
OPENCTI_TOKEN = os.getenv("OPENCTI_TOKEN", "")
RUDDER_URL = os.getenv("RUDDER_URL", "")
RUDDER_TOKEN = os.getenv("RUDDER_TOKEN", "")

WORDLISTS = {
    "dirs": "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt",
    "dirs_small": "/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt",
    "subdomains": "/usr/share/wordlists/amass/subdomains-top1mil-5000.txt",
    "passwords": "/usr/share/wordlists/rockyou.txt",
    "usernames": "/usr/share/seclists/Usernames/top-usernames-shortlist.txt",
}

SEVERITY_COLORS = {
    "Critical": "#ff0000",
    "High":     "#ff6b35",
    "Medium":   "#ffaa00",
    "Low":      "#00d4ff",
    "Info":     "#888888",
}

VERSION = "1.0.0"
AUTHOR = "GoldenAge Cybersecurity Consultancy"
CONTACT = "info@goldenage-consultancy.com"
