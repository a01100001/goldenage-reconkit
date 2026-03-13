#!/usr/bin/env bash
# GoldenAge ReconKit — Full Installer Script
# Paste this entire script into your terminal and press Enter
set -e

echo "⚡ Creating GoldenAge ReconKit..."
mkdir -p /home/kali/goldenage-reconkit/{modules,reporter,utils,output/reports,output/screenshots,output/logs}
cd /home/kali/goldenage-reconkit

cat > config.py << 'RECONEOF'
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

RECONEOF

cat > requirements.txt << 'RECONEOF'
rich>=13.0.0
requests>=2.31.0
reportlab>=4.0.0
playwright>=1.40.0
Pillow>=10.0.0

RECONEOF

cat > main.py << 'RECONEOF'
#!/usr/bin/env python3
"""
GoldenAge ReconKit — Unified Penetration Testing Framework
GoldenAge Cybersecurity Consultancy
For authorized use only.
"""

import os
import sys
import shutil
import time
import datetime

# ── Rich imports ──────────────────────────────────────────────────────────────
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.prompt import Prompt, Confirm
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeElapsedColumn
from rich.columns import Columns
from rich.text import Text
from rich import box

console = Console()

# ── Add project root to path ──────────────────────────────────────────────────
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import config
from utils.banner import print_banner
from utils.logger import setup_logger
from modules import ALL_MODULES
from reporter.html_reporter import HTMLReporter
from reporter.pdf_reporter import PDFReporter
from reporter.screenshot import ScreenshotManager
from reporter.log_reporter import LogReporter

logger = setup_logger()

# ─────────────────────────────────────────────────────────────────────────────
# DISCLAIMER
# ─────────────────────────────────────────────────────────────────────────────
DISCLAIMER = """[bold red]⚠  LEGAL DISCLAIMER[/bold red]

[yellow]GoldenAge ReconKit is intended for authorized penetration testing ONLY.
Using this tool against systems you do not own or have explicit written
permission to test is ILLEGAL and may result in criminal prosecution.

By continuing, you confirm that:
  • You own the target system, OR
  • You have written authorization from the system owner
  • You take full legal responsibility for your actions[/yellow]"""


def check_authorization():
    """Display disclaimer and require explicit confirmation."""
    console.print(Panel(DISCLAIMER, border_style="red", padding=(1, 2)))
    confirmed = Confirm.ask("\n[bold]Do you confirm you have authorization to test the target?[/bold]", default=False)
    if not confirmed:
        console.print("[red]Exiting. Obtain proper authorization first.[/red]")
        sys.exit(0)


# ─────────────────────────────────────────────────────────────────────────────
# MODULE STATUS TABLE
# ─────────────────────────────────────────────────────────────────────────────
def build_module_table(module_states):
    """Render the module enable/disable table."""
    table = Table(title="[bold cyan]Available Modules[/bold cyan]",
                  box=box.ROUNDED, border_style="cyan", show_lines=True)
    table.add_column("#", style="dim", width=4)
    table.add_column("Module", style="bold white", width=18)
    table.add_column("Description", style="dim", width=45)
    table.add_column("Available", width=11, justify="center")
    table.add_column("Enabled", width=10, justify="center")

    for i, (mod_cls, enabled) in enumerate(module_states.items(), 1):
        avail = shutil.which(config.TOOL_PATHS.get(mod_cls.name, mod_cls.name)) is not None
        avail_str = "[green]✓ Yes[/green]" if avail else "[red]✗ No[/red]"
        enabled_str = "[cyan]● ON[/cyan]" if enabled else "[dim]○ OFF[/dim]"
        table.add_row(str(i), mod_cls.name, mod_cls.description, avail_str, enabled_str)

    return table


def toggle_modules(module_states):
    """Interactive module toggle menu."""
    while True:
        console.print(build_module_table(module_states))
        choices = list(module_states.keys())
        console.print("\n[dim]Enter module number to toggle, or [bold]done[/bold] to continue.[/dim]")
        inp = Prompt.ask("[cyan]Toggle module #[/cyan]", default="done")
        if inp.lower() in ("done", "d", ""):
            break
        try:
            idx = int(inp) - 1
            if 0 <= idx < len(choices):
                mod = choices[idx]
                module_states[mod] = not module_states[mod]
                state = "enabled" if module_states[mod] else "disabled"
                console.print(f"  [cyan]→ {mod.name} {state}[/cyan]")
            else:
                console.print("[red]Invalid number[/red]")
        except ValueError:
            console.print("[red]Invalid input[/red]")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN SCAN RUNNER
# ─────────────────────────────────────────────────────────────────────────────
def run_scan(target, profile, module_states, use_proxy, sm):
    all_findings = []
    module_log = []
    enabled_modules = [cls for cls, en in module_states.items() if en]
    total = len(enabled_modules)

    console.print(f"\n[bold cyan]━━━━ Scan Started ━━━━[/bold cyan]")
    console.print(f"  [dim]Target  :[/dim] [bold]{target}[/bold]")
    console.print(f"  [dim]Profile :[/dim] [bold]{profile.upper()}[/bold]")
    console.print(f"  [dim]Proxy   :[/dim] [bold]{'BurpSuite 127.0.0.1:8080' if use_proxy else 'Disabled'}[/bold]")
    console.print(f"  [dim]Modules :[/dim] [bold]{total}[/bold]")
    console.print()

    scan_start = time.time()

    for idx, mod_cls in enumerate(enabled_modules, 1):
        console.rule(f"[cyan]Module {idx}/{total}: {mod_cls.name.upper()}[/cyan]")
        mod_start = time.time()
        log_entry = {"module": mod_cls.name, "status": "ok", "count": 0, "duration": "", "notes": ""}
        try:
            mod = mod_cls(target=target, profile=profile, use_proxy=use_proxy)
            mod.logger = logger
            findings = mod.run()

            # Browser screenshot for web-facing modules
            if mod.name in ("nikto", "whatweb", "gobuster", "feroxbuster", "burpsuite"):
                tgt_url = target if target.startswith("http") else f"http://{target}"
                ss_path = sm.capture_browser(tgt_url, label=f"{mod.name}_{target.replace('//','-').replace('/','_')}")
                for f in findings:
                    if not f.screenshot_path:
                        f.screenshot_path = ss_path

            # Terminal output → PNG snapshot
            if mod.raw_outputs:
                for i, raw in enumerate(mod.raw_outputs):
                    png = sm.capture_terminal_output(raw, label=f"{mod.name}_output_{i}")
                    # Attach first terminal screenshot to findings that have none
                    for f in findings:
                        if not f.screenshot_path and png:
                            f.screenshot_path = png
                            break

            all_findings.extend(findings)
            log_entry["count"] = len(findings)
            log_entry["status"] = "ok"

        except Exception as e:
            console.print(f"  [red]✗ Module {mod_cls.name} crashed: {e}[/red]")
            logger.error(f"Module {mod_cls.name} error: {e}", exc_info=True)
            log_entry["status"] = "error"
            log_entry["notes"] = str(e)[:60]

        mod_elapsed = time.time() - mod_start
        log_entry["duration"] = f"{mod_elapsed:.1f}s"
        module_log.append(log_entry)

    elapsed = time.time() - scan_start
    console.rule("[cyan]Scan Complete[/cyan]")
    console.print(f"\n  [green]✓ Finished in {elapsed:.1f}s — {len(all_findings)} total finding(s)[/green]\n")
    return all_findings, module_log, elapsed


# ─────────────────────────────────────────────────────────────────────────────
# REPORT GENERATOR
# ─────────────────────────────────────────────────────────────────────────────
def generate_reports(target, profile, all_findings, sm, module_log=None, elapsed=0.0):
    console.rule("[cyan]Generating Reports[/cyan]")

    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"),
                  transient=True) as progress:

        t1 = progress.add_task("Generating HTML report...", total=None)
        html_rep = HTMLReporter(target, profile, all_findings, sm.screenshots)
        html_path = html_rep.generate()
        progress.remove_task(t1)

        t2 = progress.add_task("Generating PDF report...", total=None)
        pdf_rep = PDFReporter(target, profile, all_findings)
        pdf_path = pdf_rep.generate()
        progress.remove_task(t2)

        t3 = progress.add_task("Generating text log...", total=None)
        log_rep = LogReporter(target, profile, all_findings,
                              module_log=module_log, elapsed=elapsed)
        log_path = log_rep.generate()
        progress.remove_task(t3)

    console.print(f"\n  [green]📄 HTML Report:[/green]  {html_path}")
    if pdf_path:
        console.print(f"  [green]📄 PDF Report: [/green]  {pdf_path}")
    console.print(f"  [green]📋 Text Log:   [/green]  {log_path}")
    console.print(f"  [green]📸 Screenshots:[/green]  {config.SCREENSHOTS_DIR}")
    console.print(f"  [green]📁 All outputs:[/green]  {config.OUTPUT_DIR}")
    return html_path, pdf_path, log_path


# ─────────────────────────────────────────────────────────────────────────────
# FINDINGS SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
def print_findings_summary(all_findings):
    if not all_findings:
        console.print("[dim]No findings to display.[/dim]")
        return

    table = Table(title="[bold cyan]Findings Summary[/bold cyan]",
                  box=box.ROUNDED, border_style="cyan", show_lines=True)
    table.add_column("#", style="dim", width=4)
    table.add_column("Severity", width=12)
    table.add_column("CVSS", width=8, justify="center")
    table.add_column("Tool", width=14)
    table.add_column("Title", width=55)

    severity_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Info": 4}
    sorted_f = sorted(all_findings, key=lambda f: severity_order.get(f.severity, 5))

    SEV_STYLES = {
        "Critical": "bold red",
        "High":     "bold orange1",
        "Medium":   "bold yellow",
        "Low":      "bold cyan",
        "Info":     "dim",
    }

    for i, f in enumerate(sorted_f, 1):
        style = SEV_STYLES.get(f.severity, "white")
        table.add_row(
            str(i),
            f"[{style}]{f.severity}[/{style}]",
            f"[{style}]{f.cvss_score:.1f}[/{style}]",
            f.tool,
            f.title[:55]
        )

    console.print(table)


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
def main():
    os.system("clear" if os.name != "nt" else "cls")
    print_banner()
    check_authorization()

    # ── Target ────────────────────────────────────────────────────────────────
    console.print()
    target = Prompt.ask("[bold cyan]🎯 Enter target[/bold cyan] [dim](IP, domain, or URL)[/dim]")
    if not target:
        console.print("[red]No target provided. Exiting.[/red]")
        sys.exit(1)

    # ── Profile ───────────────────────────────────────────────────────────────
    console.print("\n[bold cyan]Select scan profile:[/bold cyan]")
    for name, info in config.SCAN_PROFILES.items():
        console.print(f"  [cyan]{name:10}[/cyan] {info['description']}")

    profile = Prompt.ask("\n[bold cyan]Profile[/bold cyan]",
                         choices=list(config.SCAN_PROFILES.keys()), default="full")

    # ── Proxy ─────────────────────────────────────────────────────────────────
    use_proxy = Confirm.ask("\n[bold cyan]Route HTTP traffic through BurpSuite proxy (127.0.0.1:8080)?[/bold cyan]",
                            default=False)

    # ── Module toggle ─────────────────────────────────────────────────────────
    module_states = {cls: cls.enabled for cls in ALL_MODULES}
    customize = Confirm.ask("\n[bold cyan]Customize which modules run?[/bold cyan]", default=False)
    if customize:
        toggle_modules(module_states)
    else:
        console.print(build_module_table(module_states))

    # ── Confirm ───────────────────────────────────────────────────────────────
    console.print()
    confirmed = Confirm.ask(
        f"[bold]Ready to scan [cyan]{target}[/cyan] with profile [cyan]{profile}[/cyan]?[/bold]",
        default=True
    )
    if not confirmed:
        console.print("[dim]Scan cancelled.[/dim]")
        sys.exit(0)

    # ── Run ───────────────────────────────────────────────────────────────────
    sm = ScreenshotManager()
    all_findings, module_log, elapsed = run_scan(target, profile, module_states, use_proxy, sm)

    # ── Summary ───────────────────────────────────────────────────────────────
    print_findings_summary(all_findings)

    # ── Reports ───────────────────────────────────────────────────────────────
    html_path, pdf_path, log_path = generate_reports(
        target, profile, all_findings, sm,
        module_log=module_log, elapsed=elapsed
    )

    # ── Done ──────────────────────────────────────────────────────────────────
    console.print(f"\n[bold cyan]━━━━ GoldenAge ReconKit Complete ━━━━[/bold cyan]")
    console.print(f"[dim]Open your HTML report in any browser for the full interactive view.[/dim]\n")


if __name__ == "__main__":
    main()

RECONEOF

cat > modules/__init__.py << 'RECONEOF'
from .nmap_module import NmapModule
from .web_modules import NiktoModule, WhatwebModule, SqlmapModule
from .recon_modules import GobusterModule, FeroxbusterModule, HydraModule, BurpsuiteModule
from .intel_modules import OpenCTIModule, RudderModule

ALL_MODULES = [
    NmapModule,
    WhatwebModule,
    NiktoModule,
    GobusterModule,
    FeroxbusterModule,
    SqlmapModule,
    HydraModule,
    BurpsuiteModule,
    OpenCTIModule,
    RudderModule,
]

RECONEOF

cat > modules/base_module.py << 'RECONEOF'
import subprocess
import shutil
import os
import time
from abc import ABC, abstractmethod
from rich.console import Console
from datetime import datetime
import config

console = Console()

class Finding:
    """Represents a single vulnerability/finding."""
    def __init__(self, tool, title, description, severity, cvss_score,
                 cvss_vector="", impact="", remediation="",
                 references=None, raw_output="", finding_type="finding"):
        self.tool = tool
        self.title = title
        self.description = description
        self.severity = severity
        self.cvss_score = cvss_score
        self.cvss_vector = cvss_vector
        self.impact = impact
        self.remediation = remediation
        self.references = references or []
        self.raw_output = raw_output
        self.finding_type = finding_type
        self.screenshot_path = ""
        self.timestamp = datetime.now().isoformat()

    def to_dict(self):
        return self.__dict__


class BaseModule(ABC):
    name = "base"
    description = "Base module"
    enabled = True

    def __init__(self, target, profile="full", use_proxy=False):
        self.target = target
        self.profile = profile
        self.use_proxy = use_proxy
        self.findings = []
        self.raw_outputs = []
        self.start_time = None
        self.end_time = None
        self.logger = None

    def is_available(self):
        tool_bin = config.TOOL_PATHS.get(self.name, self.name)
        return shutil.which(tool_bin) is not None

    def run_command(self, cmd, timeout=600, shell=False):
        """Run a shell command and return stdout, stderr, returncode."""
        self.logger and self.logger.info(f"[{self.name}] Running: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
        console.print(f"  [dim]→ {' '.join(cmd) if isinstance(cmd, list) else cmd}[/dim]")
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True,
                timeout=timeout, shell=shell
            )
            return result.stdout, result.stderr, result.returncode
        except subprocess.TimeoutExpired:
            console.print(f"  [yellow]⚠ {self.name} timed out after {timeout}s[/yellow]")
            return "", "TIMEOUT", -1
        except FileNotFoundError:
            return "", f"Tool '{self.name}' not found", -1

    @abstractmethod
    def run(self):
        """Execute the module and populate self.findings."""
        pass

    def add_finding(self, **kwargs):
        f = Finding(**kwargs)
        self.findings.append(f)
        return f

    def get_proxy_args(self, tool_type="curl"):
        """Return proxy arguments for different tools."""
        if not self.use_proxy:
            return []
        proxies = {
            "curl": ["--proxy", config.BURP_PROXY],
            "wget": ["-e", f"https_proxy={config.BURP_PROXY}"],
            "python": {"http": config.BURP_PROXY, "https": config.BURP_PROXY},
        }
        return proxies.get(tool_type, [])

RECONEOF

cat > modules/nmap_module.py << 'RECONEOF'
import re
from .base_module import BaseModule, Finding
from rich.console import Console
import config

console = Console()

# Known port → CVSS / severity / description mapping
PORT_DB = {
    21:  ("FTP Service Detected", "Medium", 5.3, "FTP transmits data in plaintext. Credentials can be intercepted.",
          "AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N",
          "Replace FTP with SFTP or FTPS. Disable anonymous login.",
          ["https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=ftp",
           "https://owasp.org/www-community/vulnerabilities/Cleartext_Transmission_of_Sensitive_Information"]),
    22:  ("SSH Service Exposed", "Low", 3.7, "SSH is open. Ensure key-based auth and no root login.",
          "AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N",
          "Disable password auth, use key-based. Restrict source IPs.",
          ["https://www.ssh.com/academy/ssh/security"]),
    23:  ("Telnet Service Detected", "High", 8.1, "Telnet transmits all data including credentials in plaintext.",
          "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N",
          "Disable Telnet immediately. Use SSH instead.",
          ["https://nvd.nist.gov/vuln/search/results?query=telnet"]),
    25:  ("SMTP Service Open", "Medium", 5.3, "SMTP open - check for open relay and auth requirements.",
          "AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N",
          "Disable open relay. Require authentication for mail sending.",
          ["https://owasp.org/www-community/vulnerabilities/Email_Header_Injection"]),
    80:  ("HTTP Service (Unencrypted)", "Medium", 5.4, "Web server responding on plain HTTP. Traffic can be intercepted.",
          "AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:L/A:N",
          "Redirect all HTTP to HTTPS. Implement HSTS.",
          ["https://owasp.org/www-project-top-ten/"]),
    443: ("HTTPS Service", "Info", 0.0, "HTTPS detected. Verify TLS version and certificate validity.",
          "", "Ensure TLS 1.2+ only. Disable SSLv3/TLS 1.0/1.1.",
          ["https://www.ssllabs.com/ssltest/"]),
    445: ("SMB Service Detected", "High", 8.8, "SMB open - potential for EternalBlue, ransomware pivot.",
          "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
          "Patch MS17-010. Disable SMBv1. Block port 445 on firewall.",
          ["https://nvd.nist.gov/vuln/detail/CVE-2017-0144",
           "https://www.cisa.gov/known-exploited-vulnerabilities-catalog"]),
    1433: ("MSSQL Exposed", "Critical", 9.8, "Microsoft SQL Server port is directly accessible.",
           "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
           "Restrict MSSQL to localhost only. Use firewall rules.",
           ["https://www.rapid7.com/db/?q=mssql"]),
    3306: ("MySQL Exposed", "Critical", 9.8, "MySQL port is directly accessible from the network.",
           "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
           "Bind MySQL to 127.0.0.1. Use strong passwords.",
           ["https://nvd.nist.gov/vuln/search/results?query=mysql+remote"]),
    3389: ("RDP Service Exposed", "Critical", 9.8, "Remote Desktop open. BlueKeep risk if unpatched.",
           "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
           "Patch CVE-2019-0708. Enable NLA. Restrict via VPN.",
           ["https://nvd.nist.gov/vuln/detail/CVE-2019-0708"]),
    6379: ("Redis Exposed (Unauthenticated)", "Critical", 9.8, "Redis without auth - full data access and RCE possible.",
           "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
           "Bind to 127.0.0.1. Enable requirepass. Use ACL.",
           ["https://redis.io/topics/security"]),
    27017: ("MongoDB Exposed", "Critical", 9.8, "MongoDB with no authentication - full DB access.",
            "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
            "Enable MongoDB auth. Bind to localhost.",
            ["https://docs.mongodb.com/manual/security/"]),
}

class NmapModule(BaseModule):
    name = "nmap"
    description = "Network port scanner & service detection"
    enabled = True

    def run(self):
        console.print(f"\n[bold cyan][ NMAP ][/bold cyan] Scanning {self.target}...")
        profile_args = config.SCAN_PROFILES[self.profile]["nmap_args"].split()
        cmd = ["nmap"] + profile_args + ["-sV", "--script=vuln,banner", "-oN", "-", self.target]
        stdout, stderr, code = self.run_command(cmd, timeout=900)

        if not stdout:
            console.print(f"  [red]✗ Nmap returned no output[/red]")
            return self.findings

        self.raw_outputs.append(stdout)
        self._parse_output(stdout)
        console.print(f"  [green]✓ Nmap complete — {len(self.findings)} finding(s)[/green]")
        return self.findings

    def _parse_output(self, output):
        # Parse open ports
        open_ports = re.findall(r"(\d+)/tcp\s+open\s+(\S+)\s*(.*)", output)
        for port_str, service, version in open_ports:
            port = int(port_str)
            if port in PORT_DB:
                title, sev, cvss, desc, vector, rem, refs = PORT_DB[port]
                desc_full = desc
                if version:
                    desc_full += f"\n\nDetected version: **{version.strip()}**"
            else:
                title = f"Open Port {port} ({service})"
                sev = "Low"
                cvss = 3.1
                desc_full = f"Port {port} ({service}) is open. Version: {version.strip() or 'unknown'}"
                vector = "AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N"
                rem = "Review if this service is necessary. Apply patches."
                refs = ["https://www.shodan.io/", "https://nvd.nist.gov/"]

            self.add_finding(
                tool="nmap",
                title=title,
                description=desc_full,
                severity=sev,
                cvss_score=cvss,
                cvss_vector=vector,
                impact=f"Port {port} ({service}) is reachable from the network.",
                remediation=rem,
                references=refs,
                raw_output=output,
                finding_type="network"
            )

        # Parse NSE vuln script results
        vuln_blocks = re.findall(r"\|\s+(CVE-\d{4}-\d+)[^\n]*\n([^\|]+)", output)
        for cve, details in vuln_blocks:
            self.add_finding(
                tool="nmap",
                title=f"Vulnerability: {cve}",
                description=details.strip(),
                severity="High",
                cvss_score=7.5,
                cvss_vector="AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N",
                impact="Known CVE detected by NSE script.",
                remediation="Apply vendor patch immediately.",
                references=[f"https://nvd.nist.gov/vuln/detail/{cve}",
                            f"https://cve.mitre.org/cgi-bin/cvename.cgi?name={cve}"],
                raw_output=output,
                finding_type="vulnerability"
            )

RECONEOF

cat > modules/web_modules.py << 'RECONEOF'
import re
from .base_module import BaseModule
from rich.console import Console
import config

console = Console()

# ─── NIKTO ────────────────────────────────────────────────────────────────────

class NiktoModule(BaseModule):
    name = "nikto"
    description = "Web server vulnerability scanner"
    enabled = True

    NIKTO_SEVERITY = {
        "OSVDB": ("Medium", 5.3),
        "XSS": ("High", 7.4),
        "SQL": ("High", 8.1),
        "info": ("Info", 0.0),
        "default": ("Medium", 5.0),
    }

    def run(self):
        console.print(f"\n[bold cyan][ NIKTO ][/bold cyan] Scanning {self.target}...")
        target_url = self.target if self.target.startswith("http") else f"http://{self.target}"
        profile_args = config.SCAN_PROFILES[self.profile].get("nikto_args", "").split()
        proxy_args = ["-useproxy", config.BURP_PROXY] if self.use_proxy else []
        cmd = ["nikto", "-h", target_url, "-Format", "txt"] + profile_args + proxy_args
        stdout, stderr, code = self.run_command(cmd, timeout=600)

        if not stdout:
            console.print(f"  [red]✗ Nikto returned no output[/red]")
            return self.findings

        self.raw_outputs.append(stdout)
        self._parse_output(stdout)
        console.print(f"  [green]✓ Nikto complete — {len(self.findings)} finding(s)[/green]")
        return self.findings

    def _parse_output(self, output):
        lines = output.splitlines()
        for line in lines:
            line = line.strip()
            if not line.startswith("+"):
                continue
            line = line.lstrip("+ ")

            # Determine severity
            sev, cvss = "Medium", 5.0
            refs = ["https://www.cvedetails.com/", "https://owasp.org/www-project-top-ten/"]

            if "XSS" in line.upper() or "CROSS-SITE" in line.upper():
                sev, cvss = "High", 7.4
                refs.append("https://owasp.org/www-community/attacks/xss/")
            elif "SQL" in line.upper():
                sev, cvss = "High", 8.1
                refs.append("https://owasp.org/www-community/attacks/SQL_Injection")
            elif "OSVDB" in line:
                osvdb = re.search(r"OSVDB-(\d+)", line)
                if osvdb:
                    refs.append(f"https://vulners.com/osvdb/OSVDB-{osvdb.group(1)}")
            elif "SERVER" in line.upper() or "HEADER" in line.upper():
                sev, cvss = "Low", 3.1
            elif "ALLOW" in line.upper() or "METHOD" in line.upper():
                sev, cvss = "Medium", 5.3

            cvss_vectors = {
                "High":   "AV:N/AC:L/PR:N/UI:R/S:C/C:H/I:L/A:N",
                "Medium": "AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N",
                "Low":    "AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N",
                "Info":   "",
            }

            self.add_finding(
                tool="nikto",
                title=line[:80],
                description=line,
                severity=sev,
                cvss_score=cvss,
                cvss_vector=cvss_vectors.get(sev, ""),
                impact="Web server misconfiguration or known vulnerable component detected.",
                remediation="Review and patch the identified issue. Update web server software.",
                references=refs,
                raw_output=output,
                finding_type="web"
            )


# ─── WHATWEB ──────────────────────────────────────────────────────────────────

class WhatwebModule(BaseModule):
    name = "whatweb"
    description = "Web technology fingerprinting"
    enabled = True

    RISKY_TECHS = {
        "WordPress": ("WordPress CMS Detected", "Medium", 5.3,
                      "WordPress sites are heavily targeted. Check for outdated plugins and themes.",
                      ["https://wpscan.com/", "https://wordpress.org/about/security/"]),
        "Joomla":    ("Joomla CMS Detected", "Medium", 5.3,
                      "Joomla has a history of critical vulnerabilities. Ensure latest version.",
                      ["https://developer.joomla.org/security-centre.html"]),
        "Drupal":    ("Drupal CMS Detected", "Medium", 5.3,
                      "Check for Drupalgeddon vulnerabilities (CVE-2018-7600).",
                      ["https://nvd.nist.gov/vuln/detail/CVE-2018-7600"]),
        "PHP":       ("PHP Version Exposed", "Low", 3.7,
                      "PHP version fingerprinted. Outdated PHP versions carry critical CVEs.",
                      ["https://www.php.net/supported-versions.php"]),
        "Apache":    ("Apache Web Server Detected", "Low", 3.1,
                      "Verify Apache version is current. Check for module misconfigurations.",
                      ["https://httpd.apache.org/security/vulnerabilities_24.html"]),
        "nginx":     ("Nginx Web Server Detected", "Low", 3.1,
                      "Verify nginx version and configuration hardening.",
                      ["https://nginx.org/en/security_advisories.html"]),
        "IIS":       ("Microsoft IIS Detected", "Medium", 5.3,
                      "IIS version may be outdated. Check for WebDAV and PUT method abuse.",
                      ["https://support.microsoft.com/en-us/topic/iis-updates"]),
        "X-Powered-By": ("Server Technology Header Leaked", "Low", 3.1,
                         "X-Powered-By header exposes backend technology.",
                         ["https://owasp.org/www-project-secure-headers/"]),
    }

    def run(self):
        console.print(f"\n[bold cyan][ WHATWEB ][/bold cyan] Fingerprinting {self.target}...")
        target_url = self.target if self.target.startswith("http") else f"http://{self.target}"
        proxy_args = ["--proxy", config.BURP_PROXY] if self.use_proxy else []
        cmd = ["whatweb", "-a", "3", "--color=never", target_url] + proxy_args
        stdout, stderr, code = self.run_command(cmd, timeout=120)

        if not stdout:
            console.print(f"  [red]✗ WhatWeb returned no output[/red]")
            return self.findings

        self.raw_outputs.append(stdout)
        self._parse_output(stdout)
        console.print(f"  [green]✓ WhatWeb complete — {len(self.findings)} finding(s)[/green]")
        return self.findings

    def _parse_output(self, output):
        for tech, (title, sev, cvss, desc, refs) in self.RISKY_TECHS.items():
            if tech.lower() in output.lower():
                # Try to extract version
                version_match = re.search(rf"{tech}[\[/]([0-9.]+)", output, re.IGNORECASE)
                version_info = f" (v{version_match.group(1)})" if version_match else ""
                self.add_finding(
                    tool="whatweb",
                    title=title + version_info,
                    description=desc,
                    severity=sev,
                    cvss_score=cvss,
                    cvss_vector="AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N",
                    impact=f"{tech} fingerprinted — attacker can target known CVEs for this version.",
                    remediation="Keep software updated. Remove version-revealing headers.",
                    references=refs,
                    raw_output=output,
                    finding_type="fingerprint"
                )


# ─── SQLMAP ───────────────────────────────────────────────────────────────────

class SqlmapModule(BaseModule):
    name = "sqlmap"
    description = "SQL injection detection and exploitation"
    enabled = True

    INJECTION_TYPES = {
        "boolean-based blind":  ("Boolean-based Blind SQLi", "High", 8.1,
                                 "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N"),
        "time-based blind":     ("Time-based Blind SQLi", "High", 7.5,
                                 "AV:N/AC:H/PR:N/UI:N/S:U/C:H/I:H/A:N"),
        "error-based":          ("Error-based SQLi", "High", 8.6,
                                 "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N"),
        "UNION query-based":    ("UNION-based SQLi", "Critical", 9.8,
                                 "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H"),
        "stacked queries":      ("Stacked Query SQLi (RCE Risk)", "Critical", 9.8,
                                 "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H"),
    }

    def run(self):
        console.print(f"\n[bold cyan][ SQLMAP ][/bold cyan] Testing {self.target}...")
        target_url = self.target if self.target.startswith("http") else f"http://{self.target}"
        proxy_args = ["--proxy", config.BURP_PROXY] if self.use_proxy else []
        cmd = [
            "sqlmap", "-u", target_url,
            "--batch", "--level=3", "--risk=2",
            "--forms", "--crawl=2",
            "--output-dir=/tmp/sqlmap_out",
            "--random-agent"
        ] + proxy_args

        stdout, stderr, code = self.run_command(cmd, timeout=600)
        combined = stdout + stderr
        if not combined:
            console.print(f"  [red]✗ SQLMap returned no output[/red]")
            return self.findings

        self.raw_outputs.append(combined)
        self._parse_output(combined)
        console.print(f"  [green]✓ SQLMap complete — {len(self.findings)} finding(s)[/green]")
        return self.findings

    def _parse_output(self, output):
        param_match = re.search(r"Parameter: (\S+) \((.+?)\)", output)
        for inj_type, (title, sev, cvss, vector) in self.INJECTION_TYPES.items():
            if inj_type.lower() in output.lower():
                param = param_match.group(1) if param_match else "unknown"
                self.add_finding(
                    tool="sqlmap",
                    title=f"{title} — Parameter: {param}",
                    description=(
                        f"SQL injection vulnerability detected via **{inj_type}** technique.\n\n"
                        f"Affected parameter: `{param}`\n\n"
                        "An attacker can read, modify, or delete database contents. "
                        "Depending on DB privileges, OS-level access may be possible (xp_cmdshell, INTO OUTFILE, etc.)."
                    ),
                    severity=sev,
                    cvss_score=cvss,
                    cvss_vector=vector,
                    impact="Full database compromise. Potential for authentication bypass, data exfiltration, and in some cases remote code execution.",
                    remediation=(
                        "1. Use parameterized queries / prepared statements\n"
                        "2. Implement input validation and output encoding\n"
                        "3. Apply principle of least privilege to DB accounts\n"
                        "4. Use WAF as defense-in-depth"
                    ),
                    references=[
                        "https://owasp.org/www-community/attacks/SQL_Injection",
                        "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html",
                        "https://nvd.nist.gov/vuln/search/results?query=sql+injection",
                        "https://cwe.mitre.org/data/definitions/89.html"
                    ],
                    raw_output=output,
                    finding_type="vulnerability"
                )

RECONEOF

cat > modules/recon_modules.py << 'RECONEOF'
import re
import os
import shutil
import subprocess
from .base_module import BaseModule
from rich.console import Console
import config

console = Console()

# ─── GOBUSTER ─────────────────────────────────────────────────────────────────

class GobusterModule(BaseModule):
    name = "gobuster"
    description = "Directory and file brute-forcer"
    enabled = True

    SENSITIVE_PATHS = {
        "/admin": ("Admin Panel Exposed", "High", 8.1),
        "/login": ("Login Page Discovered", "Medium", 5.3),
        "/backup": ("Backup Directory Exposed", "Critical", 9.1),
        "/.git": ("Git Repository Exposed", "Critical", 9.8),
        "/wp-admin": ("WordPress Admin Panel", "High", 8.1),
        "/phpmyadmin": ("phpMyAdmin Exposed", "Critical", 9.8),
        "/api": ("API Endpoint Discovered", "Medium", 6.5),
        "/config": ("Config Directory Exposed", "High", 8.6),
        "/.env": (".env File Exposed", "Critical", 9.8),
        "/uploads": ("Upload Directory Exposed", "High", 7.5),
        "/test": ("Test Directory Found", "Medium", 5.0),
        "/old": ("Old/Archive Directory Found", "Medium", 5.3),
        "/db": ("Database Directory Exposed", "Critical", 9.8),
        "/swagger": ("Swagger UI Exposed", "Medium", 6.5),
        "/actuator": ("Spring Actuator Exposed", "High", 8.6),
    }

    def run(self):
        console.print(f"\n[bold cyan][ GOBUSTER ][/bold cyan] Dir busting {self.target}...")
        target_url = self.target if self.target.startswith("http") else f"http://{self.target}"
        profile_args = config.SCAN_PROFILES[self.profile].get("gobuster_args", "-t 30").split()
        wordlist = config.WORDLISTS["dirs_small"] if self.profile == "quick" else config.WORDLISTS["dirs"]

        if not os.path.exists(wordlist):
            wordlist = "/usr/share/wordlists/dirb/common.txt"

        proxy_args = ["--proxy", config.BURP_PROXY] if self.use_proxy else []
        cmd = (["gobuster", "dir", "-u", target_url, "-w", wordlist,
                "-x", "php,html,js,txt,bak,zip,tar,gz,json,xml,yml,env",
                "--no-error", "-q"] + profile_args + proxy_args)

        stdout, stderr, code = self.run_command(cmd, timeout=600)
        if not stdout:
            console.print(f"  [red]✗ Gobuster returned no output[/red]")
            return self.findings

        self.raw_outputs.append(stdout)
        self._parse_output(stdout)
        console.print(f"  [green]✓ Gobuster complete — {len(self.findings)} finding(s)[/green]")
        return self.findings

    def _parse_output(self, output):
        lines = output.splitlines()
        for line in lines:
            m = re.search(r"(/\S+)\s+\(Status:\s*(\d+)\)", line)
            if not m:
                continue
            path, status = m.group(1), m.group(2)
            if status in ("404", "400"):
                continue

            # Check if sensitive
            matched_key = next((k for k in self.SENSITIVE_PATHS if path.lower().startswith(k.lower())), None)
            if matched_key:
                title, sev, cvss = self.SENSITIVE_PATHS[matched_key]
                desc = (f"Sensitive path `{path}` returned HTTP {status}.\n\n"
                        f"This endpoint may expose administrative interfaces, credentials, or source code.")
                refs = [
                    "https://owasp.org/www-project-top-ten/",
                    "https://cwe.mitre.org/data/definitions/538.html",
                    "https://owasp.org/www-community/attacks/Path_Traversal"
                ]
            else:
                title = f"Directory/File Found: {path}"
                sev = "Low"
                cvss = 3.1
                desc = f"Path `{path}` is accessible (HTTP {status}). Review if it should be public."
                refs = ["https://owasp.org/www-project-top-ten/"]

            self.add_finding(
                tool="gobuster",
                title=title,
                description=desc,
                severity=sev,
                cvss_score=cvss,
                cvss_vector="AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N" if sev in ("Critical","High") else "AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N",
                impact=f"Unauthorized users can access {path}.",
                remediation="Restrict access via authentication or IP allowlist. Remove unnecessary files.",
                references=refs,
                raw_output=line,
                finding_type="web"
            )


# ─── FEROXBUSTER ──────────────────────────────────────────────────────────────

class FeroxbusterModule(BaseModule):
    name = "feroxbuster"
    description = "Recursive web content discovery (proxy-aware)"
    enabled = True

    def run(self):
        console.print(f"\n[bold cyan][ FEROXBUSTER ][/bold cyan] Recursive scan on {self.target}...")
        target_url = self.target if self.target.startswith("http") else f"http://{self.target}"
        profile_args = config.SCAN_PROFILES[self.profile].get("feroxbuster_args", "--depth 3").split()
        wordlist = config.WORDLISTS["dirs_small"] if self.profile == "quick" else config.WORDLISTS["dirs"]

        if not os.path.exists(wordlist):
            wordlist = "/usr/share/wordlists/dirb/common.txt"

        proxy_args = ["--proxy", config.BURP_PROXY] if self.use_proxy else []
        output_file = "/tmp/ferox_output.txt"
        cmd = (["feroxbuster", "-u", target_url, "-w", wordlist,
                "-x", "php,html,js,json,env,bak,zip",
                "--no-state", "--quiet", "-o", output_file] + profile_args + proxy_args)

        stdout, stderr, code = self.run_command(cmd, timeout=600)
        # Read from output file if exists
        if os.path.exists(output_file):
            with open(output_file) as f:
                stdout = f.read()

        if not stdout:
            console.print(f"  [red]✗ Feroxbuster returned no output[/red]")
            return self.findings

        self.raw_outputs.append(stdout)
        self._parse_output(stdout)
        console.print(f"  [green]✓ Feroxbuster complete — {len(self.findings)} finding(s)[/green]")
        return self.findings

    def _parse_output(self, output):
        CRITICAL_PATHS = ["/api/v", "/internal", "/backup", "/.git", "/.env", "/admin", "/db", "/secret"]
        for line in output.splitlines():
            m = re.search(r"(\d{3})\s+\S+\s+\S+\s+(https?://\S+)", line)
            if not m:
                continue
            status, url = m.group(1), m.group(2)
            if status in ("404", "400", "000"):
                continue
            path = url.split("/", 3)[-1] if "/" in url else url

            is_critical = any(c in path.lower() for c in CRITICAL_PATHS)
            sev = "Critical" if is_critical else ("Medium" if status == "200" else "Low")
            cvss = 9.1 if is_critical else (5.3 if status == "200" else 3.1)

            self.add_finding(
                tool="feroxbuster",
                title=f"{'[RECURSIVE] ' if is_critical else ''}Hidden Path: /{path}",
                description=(
                    f"Feroxbuster discovered `{url}` via recursive brute-force (HTTP {status}).\n\n"
                    + ("⚠ This path matches a **high-risk pattern** (API, internal, backup, secret)." if is_critical else "")
                ),
                severity=sev,
                cvss_score=cvss,
                cvss_vector="AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N" if is_critical else "AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N",
                impact="Hidden endpoint discovered — may expose sensitive data or internal APIs.",
                remediation="Block or authenticate this endpoint. Review web server config.",
                references=[
                    "https://owasp.org/www-community/attacks/Forced_browsing",
                    "https://github.com/epi052/feroxbuster"
                ],
                raw_output=line,
                finding_type="web"
            )


# ─── HYDRA ────────────────────────────────────────────────────────────────────

class HydraModule(BaseModule):
    name = "hydra"
    description = "Credential brute-force (SSH, FTP, HTTP, RDP)"
    enabled = True

    def run(self):
        console.print(f"\n[bold cyan][ HYDRA ][/bold cyan] Credential testing on {self.target}...")
        console.print("  [yellow]⚠ Hydra requires a service and credentials list.[/yellow]")
        console.print("  [dim]Skipping auto-run — use Hydra manually with specific service/wordlist.[/dim]")
        console.print("  [dim]Example: hydra -L users.txt -P rockyou.txt ssh://target[/dim]")

        # Register an informational finding about exposed services
        self.add_finding(
            tool="hydra",
            title="Credential Brute-Force Testing Recommended",
            description=(
                "Hydra is configured and ready for credential testing. "
                "Provide a service target (ssh, ftp, http-post-form, rdp) and wordlist.\n\n"
                "Common default credentials to test:\n"
                "- admin:admin, admin:password, root:root, admin:1234"
            ),
            severity="Info",
            cvss_score=0.0,
            impact="If default credentials are accepted, full system compromise is possible.",
            remediation=(
                "1. Enforce strong password policies\n"
                "2. Implement account lockout after failed attempts\n"
                "3. Use MFA for all remote access\n"
                "4. Disable default accounts"
            ),
            references=[
                "https://owasp.org/www-community/attacks/Credential_stuffing",
                "https://github.com/vanhauser-thc/thc-hydra"
            ],
            raw_output="Hydra not auto-executed (requires service-specific config)",
            finding_type="info"
        )
        return self.findings


# ─── BURPSUITE ────────────────────────────────────────────────────────────────

class BurpsuiteModule(BaseModule):
    name = "burpsuite"
    description = "Proxy and HTTP traffic interception (Community Edition)"
    enabled = True

    def run(self):
        console.print(f"\n[bold cyan][ BURPSUITE ][/bold cyan] Configuring proxy for {self.target}...")

        # Check if BurpSuite is running by trying to connect to proxy
        import socket
        burp_running = False
        try:
            s = socket.create_connection(("127.0.0.1", 8080), timeout=2)
            s.close()
            burp_running = True
        except Exception:
            pass

        if burp_running:
            console.print("  [green]✓ BurpSuite proxy detected on 127.0.0.1:8080[/green]")
            console.print("  [cyan]→ All HTTP modules will route through Burp[/cyan]")
            self.add_finding(
                tool="burpsuite",
                title="BurpSuite Proxy Active — Traffic Interception Enabled",
                description=(
                    "BurpSuite Community Edition is running at `127.0.0.1:8080`. "
                    "All subsequent HTTP tool requests are proxied for analysis.\n\n"
                    "Review Burp's 'Proxy > HTTP History' for captured requests."
                ),
                severity="Info",
                cvss_score=0.0,
                impact="All HTTP traffic to target is captured for manual analysis.",
                remediation="Review intercepted traffic for sensitive data in transit.",
                references=["https://portswigger.net/burp"],
                raw_output="Proxy active on 127.0.0.1:8080",
                finding_type="info"
            )
        else:
            console.print("  [yellow]⚠ BurpSuite not detected on port 8080[/yellow]")
            console.print("  [dim]→ Start BurpSuite and enable proxy on 127.0.0.1:8080[/dim]")
            self.add_finding(
                tool="burpsuite",
                title="BurpSuite Proxy Not Running",
                description=(
                    "BurpSuite proxy was not detected on 127.0.0.1:8080. "
                    "Start BurpSuite Community Edition and configure the proxy listener "
                    "before running HTTP-based scans for full traffic capture."
                ),
                severity="Info",
                cvss_score=0.0,
                impact="HTTP traffic will not be captured for manual analysis.",
                remediation="Launch BurpSuite, go to Proxy > Options, enable listener on 8080.",
                references=["https://portswigger.net/burp/documentation/desktop/getting-started"],
                raw_output="No proxy at 127.0.0.1:8080",
                finding_type="info"
            )
        return self.findings

RECONEOF

cat > modules/intel_modules.py << 'RECONEOF'
import re
import json
import requests
from .base_module import BaseModule
from rich.console import Console
import config

console = Console()

# ─── OPENCTI ──────────────────────────────────────────────────────────────────

class OpenCTIModule(BaseModule):
    name = "opencti"
    description = "Threat intelligence lookup via OpenCTI"
    enabled = True

    GRAPHQL_QUERY = """
    query SearchIndicators($search: String) {
      indicators(search: $search, first: 10) {
        edges {
          node {
            id
            name
            description
            pattern
            valid_from
            valid_until
            confidence
            x_opencti_score
            objectLabel { edges { node { value color } } }
            killChainPhases { edges { node { phase_name kill_chain_name } } }
          }
        }
      }
    }
    """

    def run(self):
        console.print(f"\n[bold cyan][ OPENCTI ][/bold cyan] Threat intelligence lookup for {self.target}...")
        if not config.OPENCTI_URL or not config.OPENCTI_TOKEN:
            console.print("  [yellow]⚠ OPENCTI_URL / OPENCTI_TOKEN not configured[/yellow]")
            console.print("  [dim]Set env vars: export OPENCTI_URL=https://your-opencti.io[/dim]")
            console.print("  [dim]            export OPENCTI_TOKEN=your-api-token[/dim]")
            self.add_finding(
                tool="opencti",
                title="OpenCTI Not Configured",
                description=(
                    "OpenCTI threat intelligence platform is not configured.\n\n"
                    "To enable threat intel lookups:\n"
                    "```\nexport OPENCTI_URL=https://your-opencti-instance.io\n"
                    "export OPENCTI_TOKEN=your-api-token\n```\n\n"
                    "OpenCTI can correlate target IPs/domains against known threat actor TTPs, "
                    "malware indicators, and MITRE ATT&CK techniques."
                ),
                severity="Info",
                cvss_score=0.0,
                impact="Threat intelligence context unavailable.",
                remediation="Configure OpenCTI integration for enriched threat context.",
                references=["https://docs.opencti.io/", "https://github.com/OpenCTI-Platform/opencti"],
                raw_output="Not configured",
                finding_type="info"
            )
            return self.findings

        try:
            headers = {
                "Authorization": f"Bearer {config.OPENCTI_TOKEN}",
                "Content-Type": "application/json"
            }
            resp = requests.post(
                f"{config.OPENCTI_URL}/graphql",
                json={"query": self.GRAPHQL_QUERY, "variables": {"search": self.target}},
                headers=headers,
                timeout=30,
                verify=False
            )
            data = resp.json()
            indicators = data.get("data", {}).get("indicators", {}).get("edges", [])

            if not indicators:
                console.print(f"  [dim]No threat intel found for {self.target}[/dim]")
                return self.findings

            for edge in indicators:
                node = edge["node"]
                score = node.get("x_opencti_score", 0)
                labels = [e["node"]["value"] for e in node.get("objectLabel", {}).get("edges", [])]
                kill_chain = [e["node"]["phase_name"] for e in node.get("killChainPhases", {}).get("edges", [])]

                sev = "Critical" if score >= 80 else "High" if score >= 60 else "Medium"
                cvss = 9.0 if score >= 80 else 7.5 if score >= 60 else 5.0

                self.add_finding(
                    tool="opencti",
                    title=f"Threat Intel Match: {node['name'][:60]}",
                    description=(
                        f"{node.get('description', 'No description')}\n\n"
                        f"**Pattern:** `{node.get('pattern', 'N/A')}`\n"
                        f"**Labels:** {', '.join(labels) or 'None'}\n"
                        f"**Kill Chain Phases:** {', '.join(kill_chain) or 'Unknown'}\n"
                        f"**Confidence:** {node.get('confidence', 0)}%\n"
                        f"**Threat Score:** {score}/100"
                    ),
                    severity=sev,
                    cvss_score=cvss,
                    cvss_vector="AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H",
                    impact="Target matches known threat intelligence indicators.",
                    remediation="Correlate with internal SIEM. Investigate and isolate if confirmed.",
                    references=[
                        "https://attack.mitre.org/",
                        f"{config.OPENCTI_URL}/dashboard/observations/indicators/{node['id']}"
                    ],
                    raw_output=json.dumps(node, indent=2),
                    finding_type="threat_intel"
                )

            console.print(f"  [green]✓ OpenCTI — {len(self.findings)} threat intel finding(s)[/green]")
        except Exception as e:
            console.print(f"  [red]✗ OpenCTI error: {e}[/red]")

        return self.findings


# ─── RUDDER ───────────────────────────────────────────────────────────────────

class RudderModule(BaseModule):
    name = "rudder"
    description = "Patch compliance check via Rudder.io"
    enabled = True

    def run(self):
        console.print(f"\n[bold cyan][ RUDDER ][/bold cyan] Patch compliance check for {self.target}...")
        if not config.RUDDER_URL or not config.RUDDER_TOKEN:
            console.print("  [yellow]⚠ RUDDER_URL / RUDDER_TOKEN not configured[/yellow]")
            console.print("  [dim]Set env vars: export RUDDER_URL=https://your-rudder-server[/dim]")
            console.print("  [dim]            export RUDDER_TOKEN=your-api-token[/dim]")
            self.add_finding(
                tool="rudder",
                title="Rudder.io Patch Management Not Configured",
                description=(
                    "Rudder.io is not configured. Rudder provides automated patch compliance "
                    "checking and can identify services requiring updates on the target host.\n\n"
                    "To enable:\n"
                    "```\nexport RUDDER_URL=https://your-rudder-server\n"
                    "export RUDDER_TOKEN=your-api-token\n```\n\n"
                    "Once configured, ReconKit will:\n"
                    "- Query patch compliance status for the target node\n"
                    "- List non-compliant/vulnerable services needing patching\n"
                    "- Map unpatched services to CVSS scores\n"
                    "- Include patch recommendations in the final report"
                ),
                severity="Info",
                cvss_score=0.0,
                impact="Patch status of target system is unknown.",
                remediation="Configure Rudder integration to automate patch compliance reporting.",
                references=[
                    "https://www.rudder.io/",
                    "https://docs.rudder.io/api/",
                    "https://github.com/Normation/rudder"
                ],
                raw_output="Not configured",
                finding_type="info"
            )
            return self.findings

        try:
            headers = {
                "X-API-Token": config.RUDDER_TOKEN,
                "Content-Type": "application/json"
            }
            # Search for node by IP/hostname
            resp = requests.get(
                f"{config.RUDDER_URL}/rudder/api/latest/nodes",
                params={"where": json.dumps([{"objectType": "node", "attribute": "ipAddresses",
                                              "comparator": "regex", "value": self.target}])},
                headers=headers, timeout=30, verify=False
            )
            data = resp.json()
            nodes = data.get("data", {}).get("nodes", [])

            if not nodes:
                console.print(f"  [dim]Target not found in Rudder inventory[/dim]")
                return self.findings

            node = nodes[0]
            node_id = node["id"]

            # Get compliance for this node
            comp_resp = requests.get(
                f"{config.RUDDER_URL}/rudder/api/latest/compliance/nodes/{node_id}",
                headers=headers, timeout=30, verify=False
            )
            comp_data = comp_resp.json()
            compliance = comp_data.get("data", {}).get("nodes", [{}])[0]
            score = compliance.get("compliance", 100)
            details = compliance.get("complianceDetails", {})

            non_compliant = details.get("nonCompliantReports", 0)
            error_count = details.get("error", 0)

            sev = "Critical" if score < 50 else "High" if score < 70 else "Medium" if score < 90 else "Low"
            cvss = 9.0 if score < 50 else 7.0 if score < 70 else 5.0 if score < 90 else 3.0

            self.add_finding(
                tool="rudder",
                title=f"Patch Compliance: {score:.1f}% — {node.get('hostname', self.target)}",
                description=(
                    f"**Node:** {node.get('hostname')} ({self.target})\n"
                    f"**OS:** {node.get('os', {}).get('fullName', 'Unknown')}\n"
                    f"**Compliance Score:** {score:.1f}%\n"
                    f"**Non-compliant rules:** {non_compliant}\n"
                    f"**Errors:** {error_count}\n\n"
                    "Low compliance score indicates unpatched or misconfigured services that may be exploitable."
                ),
                severity=sev,
                cvss_score=cvss,
                cvss_vector="AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
                impact=f"Node is {100-score:.1f}% non-compliant — unpatched services may be vulnerable.",
                remediation=(
                    "1. Log into Rudder dashboard and review non-compliant rules\n"
                    "2. Apply pending patches via Rudder deployment\n"
                    "3. Schedule automatic remediation for critical patches"
                ),
                references=[
                    "https://www.rudder.io/",
                    f"{config.RUDDER_URL}/rudder/secure/nodeManager/searchNodes#{node_id}"
                ],
                raw_output=json.dumps(comp_data, indent=2),
                finding_type="patch_compliance"
            )
            console.print(f"  [green]✓ Rudder — compliance: {score:.1f}%[/green]")

        except Exception as e:
            console.print(f"  [red]✗ Rudder error: {e}[/red]")

        return self.findings

RECONEOF

cat > reporter/__init__.py << 'RECONEOF'
from .html_reporter import HTMLReporter
from .pdf_reporter import PDFReporter
from .screenshot import ScreenshotManager
from .log_reporter import LogReporter

RECONEOF

cat > reporter/screenshot.py << 'RECONEOF'
import os
import subprocess
import base64
import time
from datetime import datetime
from rich.console import Console
import config

console = Console()

class ScreenshotManager:
    def __init__(self):
        self.screenshots = []
        self.playwright_available = self._check_playwright()

    def _check_playwright(self):
        try:
            import playwright
            return True
        except ImportError:
            return False

    def capture_terminal_output(self, text, label="output"):
        """Save terminal output as PNG image using Pillow (embeddable in HTML/PDF)."""
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        png_path = os.path.join(config.SCREENSHOTS_DIR, f"{label}_{ts}.png")
        txt_path = os.path.join(config.SCREENSHOTS_DIR, f"{label}_{ts}.txt")

        # Always save .txt as fallback
        try:
            with open(txt_path, "w", encoding="utf-8") as f:
                f.write(f"=== {label} — {datetime.now().isoformat()} ===\n\n{text}")
        except Exception:
            pass

        # Try Pillow → PNG
        try:
            from PIL import Image, ImageDraw, ImageFont

            BG      = (10, 14, 26)       # #0a0e1a
            FG      = (110, 231, 183)    # terminal green
            HEADER  = (0, 212, 255)      # cyan
            FONT_SZ = 13
            PAD     = 16

            # Try to use a monospace font, fall back to default
            font = None
            for font_path in [
                "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
                "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
                "/System/Library/Fonts/Menlo.ttc",
                "C:\\Windows\\Fonts\\consola.ttf",
            ]:
                if os.path.exists(font_path):
                    try:
                        font = ImageFont.truetype(font_path, FONT_SZ)
                    except Exception:
                        pass
                    break
            if font is None:
                font = ImageFont.load_default()

            header_line = f"  ⚡ GoldenAge ReconKit  |  {label}  |  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
            lines = [header_line, "─" * 90] + text.splitlines()[:120]  # cap at 120 lines

            line_h = FONT_SZ + 5
            img_w  = max(900, max((len(l) for l in lines), default=80) * 8 + PAD * 2)
            img_h  = len(lines) * line_h + PAD * 2 + 10

            img  = Image.new("RGB", (img_w, img_h), color=BG)
            draw = ImageDraw.Draw(img)

            for i, line in enumerate(lines):
                y = PAD + i * line_h
                color = HEADER if i <= 1 else FG
                draw.text((PAD, y), line, fill=color, font=font)

            img.save(png_path)
            self.screenshots.append({"label": label, "path": png_path, "type": "terminal"})
            console.print(f"  [green]🖥  Terminal screenshot saved: {os.path.basename(png_path)}[/green]")
            return png_path

        except ImportError:
            console.print("  [yellow]⚠ Pillow not installed — terminal output saved as .txt[/yellow]")
            self.screenshots.append({"label": label, "path": txt_path, "type": "terminal_txt"})
            return txt_path
        except Exception as e:
            console.print(f"  [red]Terminal screenshot error: {e}[/red]")
            return txt_path

    def capture_browser(self, url, label="browser"):
        """Capture a browser screenshot using Playwright."""
        if not self.playwright_available:
            console.print("  [yellow]⚠ Playwright not installed — install with: pip install playwright && playwright install chromium[/yellow]")
            return ""

        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        fname = f"{label}_{ts}.png"
        fpath = os.path.join(config.SCREENSHOTS_DIR, fname)

        try:
            from playwright.sync_api import sync_playwright
            with sync_playwright() as p:
                browser = p.chromium.launch(
                    headless=True,
                    args=["--ignore-certificate-errors", "--no-sandbox"]
                )
                page = browser.new_page(viewport={"width": 1280, "height": 900})
                page.goto(url, timeout=15000, wait_until="networkidle")
                time.sleep(1)
                page.screenshot(path=fpath, full_page=True)
                browser.close()
                self.screenshots.append({"label": label, "path": fpath, "type": "browser", "url": url})
                console.print(f"  [green]📸 Screenshot saved: {fname}[/green]")
                return fpath
        except Exception as e:
            console.print(f"  [red]Browser screenshot failed: {e}[/red]")
            return ""

    def screenshot_to_base64(self, path):
        """Convert image file to base64 string for embedding in HTML."""
        if not path or not os.path.exists(path):
            return ""
        ext = os.path.splitext(path)[1].lower().lstrip(".")
        mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg"}.get(ext, "image/png")
        with open(path, "rb") as f:
            data = base64.b64encode(f.read()).decode()
        return f"data:{mime};base64,{data}"

RECONEOF

cat > reporter/html_reporter.py << 'RECONEOF'
import os
import json
from datetime import datetime
from collections import Counter
from reporter.screenshot import ScreenshotManager
import config

class HTMLReporter:
    def __init__(self, target, profile, findings, screenshots=None):
        self.target = target
        self.profile = profile
        self.findings = findings
        self.screenshots = screenshots or []
        self.sm = ScreenshotManager()
        self.ts = datetime.now()

    def _severity_badge(self, sev):
        colors = config.SEVERITY_COLORS
        c = colors.get(sev, "#888")
        return f'<span class="badge" style="background:{c}">{sev}</span>'

    def _cvss_bar(self, score):
        if score == 0:
            return ""
        pct = min(score / 10 * 100, 100)
        color = "#ff0000" if score >= 9 else "#ff6b35" if score >= 7 else "#ffaa00" if score >= 4 else "#00d4ff"
        return f'''<div class="cvss-bar-wrap">
            <div class="cvss-bar" style="width:{pct}%;background:{color}"></div>
            <span class="cvss-score">{score:.1f}</span>
        </div>'''

    def _finding_cards(self):
        if not self.findings:
            return '<p style="color:#888;text-align:center;padding:40px">No findings recorded.</p>'

        cards = []
        severity_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Info": 4}
        sorted_findings = sorted(self.findings, key=lambda f: severity_order.get(f.severity, 5))

        for i, f in enumerate(sorted_findings):
            sev_color = config.SEVERITY_COLORS.get(f.severity, "#888")
            refs_html = "".join(f'<a href="{r}" target="_blank" class="ref-link">{r}</a>' for r in (f.references or []))
            
            # Screenshot embed
            ss_html = ""
            if f.screenshot_path and os.path.exists(f.screenshot_path):
                b64 = self.sm.screenshot_to_base64(f.screenshot_path)
                if b64:
                    ss_html = f'<div class="screenshot-wrap"><img src="{b64}" alt="Screenshot" class="screenshot-img"/></div>'

            raw_html = f'<pre class="raw-output">{f.raw_output[:2000] if f.raw_output else "N/A"}</pre>' if f.raw_output else ""

            desc_html = (f.description or "").replace("\n", "<br>").replace("**", "<strong>").replace("**", "</strong>")

            cards.append(f'''
            <div class="finding-card" id="finding-{i}">
                <div class="finding-header" style="border-left:4px solid {sev_color}">
                    <div class="finding-title-row">
                        <span class="finding-num">#{i+1}</span>
                        <h3 class="finding-title">{f.title}</h3>
                        {self._severity_badge(f.severity)}
                    </div>
                    <div class="finding-meta">
                        <span class="meta-item">🛠 {f.tool.upper()}</span>
                        <span class="meta-item">📅 {f.timestamp[:19].replace("T"," ")}</span>
                        <span class="meta-item">🔖 {f.finding_type}</span>
                    </div>
                </div>
                <div class="finding-body">
                    <div class="finding-grid">
                        <div class="finding-col">
                            <h4>📋 Description</h4>
                            <p>{desc_html}</p>
                            <h4>💥 Impact</h4>
                            <p>{f.impact or "N/A"}</p>
                            <h4>🔧 Remediation</h4>
                            <p>{(f.remediation or "N/A").replace(chr(10), "<br>")}</p>
                        </div>
                        <div class="finding-col">
                            <h4>📊 CVSS Score</h4>
                            {self._cvss_bar(f.cvss_score)}
                            <p class="cvss-vector">{f.cvss_vector or "N/A"}</p>
                            <h4>🔗 References</h4>
                            <div class="refs">{refs_html or "None"}</div>
                        </div>
                    </div>
                    {ss_html}
                    <details class="raw-details">
                        <summary>Raw Tool Output</summary>
                        {raw_html}
                    </details>
                </div>
            </div>''')

        return "\n".join(cards)

    def _summary_stats(self):
        counts = Counter(f.severity for f in self.findings)
        total = len(self.findings)
        avg_cvss = sum(f.cvss_score for f in self.findings) / total if total else 0
        tools_used = list(set(f.tool for f in self.findings))
        risk = "CRITICAL" if counts.get("Critical", 0) > 0 else \
               "HIGH" if counts.get("High", 0) > 0 else \
               "MEDIUM" if counts.get("Medium", 0) > 0 else "LOW"
        risk_colors = {"CRITICAL": "#ff0000", "HIGH": "#ff6b35", "MEDIUM": "#ffaa00", "LOW": "#00d4ff"}
        risk_color = risk_colors[risk]

        stat_cards = ""
        for sev in ["Critical", "High", "Medium", "Low", "Info"]:
            c = counts.get(sev, 0)
            col = config.SEVERITY_COLORS.get(sev, "#888")
            stat_cards += f'<div class="stat-card" style="border-top:3px solid {col}"><div class="stat-num" style="color:{col}">{c}</div><div class="stat-label">{sev}</div></div>'

        return stat_cards, total, avg_cvss, tools_used, risk, risk_color

    def generate(self, output_path=None):
        if not output_path:
            ts = self.ts.strftime("%Y%m%d_%H%M%S")
            output_path = os.path.join(config.REPORTS_DIR, f"goldenage_report_{self.target.replace('/','-')}_{ts}.html")

        stat_cards, total, avg_cvss, tools_used, risk, risk_color = self._summary_stats()
        finding_cards = self._finding_cards()

        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GoldenAge ReconKit — Pentest Report: {self.target}</title>
<style>
  :root {{
    --bg: #0a0e1a; --bg2: #0f1629; --bg3: #141d35;
    --cyan: #00d4ff; --orange: #ff6b35; --purple: #7b2ff7;
    --text: #e0e6f0; --text-dim: #8892a4; --border: #1e2d4a;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: 'Segoe UI', system-ui, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; }}
  
  /* HEADER */
  .header {{ background: linear-gradient(135deg, #050810, #0f1629, #1a0530);
    border-bottom: 1px solid var(--border); padding: 30px 40px;
    display: flex; align-items: center; justify-content: space-between; }}
  .header-logo {{ font-size: 24px; font-weight: 800; letter-spacing: 2px; }}
  .header-logo span {{ color: var(--cyan); }}
  .header-sub {{ color: var(--text-dim); font-size: 13px; margin-top: 4px; }}
  .risk-badge {{ font-size: 20px; font-weight: 900; padding: 10px 24px;
    border: 2px solid {risk_color}; color: {risk_color}; border-radius: 6px;
    text-shadow: 0 0 20px {risk_color}44; letter-spacing: 3px; }}

  /* NAV */
  .nav {{ background: var(--bg2); border-bottom: 1px solid var(--border);
    padding: 0 40px; display: flex; gap: 0; }}
  .nav a {{ color: var(--text-dim); text-decoration: none; padding: 14px 20px;
    font-size: 13px; border-bottom: 2px solid transparent; display: block; }}
  .nav a:hover {{ color: var(--cyan); border-bottom-color: var(--cyan); }}

  /* MAIN */
  .main {{ max-width: 1400px; margin: 0 auto; padding: 30px 40px; }}

  /* OVERVIEW */
  .overview-grid {{ display: grid; grid-template-columns: 2fr 1fr; gap: 24px; margin-bottom: 30px; }}
  .card {{ background: var(--bg2); border: 1px solid var(--border); border-radius: 10px; padding: 24px; }}
  .card h2 {{ font-size: 14px; text-transform: uppercase; letter-spacing: 2px;
    color: var(--cyan); margin-bottom: 16px; }}
  .target-info td {{ padding: 6px 0; color: var(--text-dim); font-size: 14px; }}
  .target-info td:first-child {{ color: var(--text); font-weight: 600; width: 140px; }}
  
  /* STATS */
  .stats-row {{ display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 30px; }}
  .stat-card {{ background: var(--bg2); border: 1px solid var(--border); border-radius: 8px;
    padding: 16px 20px; text-align: center; flex: 1; min-width: 100px; }}
  .stat-num {{ font-size: 32px; font-weight: 800; }}
  .stat-label {{ font-size: 12px; color: var(--text-dim); text-transform: uppercase; letter-spacing: 1px; margin-top: 4px; }}

  /* FINDINGS */
  .section-title {{ font-size: 14px; text-transform: uppercase; letter-spacing: 2px;
    color: var(--cyan); margin: 30px 0 16px; padding-bottom: 8px;
    border-bottom: 1px solid var(--border); }}
  .finding-card {{ background: var(--bg2); border: 1px solid var(--border);
    border-radius: 10px; margin-bottom: 16px; overflow: hidden; }}
  .finding-header {{ padding: 16px 20px; background: var(--bg3); }}
  .finding-title-row {{ display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }}
  .finding-num {{ color: var(--text-dim); font-size: 13px; }}
  .finding-title {{ font-size: 16px; font-weight: 600; flex: 1; }}
  .finding-meta {{ display: flex; gap: 16px; margin-top: 8px; }}
  .meta-item {{ font-size: 12px; color: var(--text-dim); }}
  .finding-body {{ padding: 20px; }}
  .finding-grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }}
  .finding-col h4 {{ font-size: 12px; text-transform: uppercase; letter-spacing: 1px;
    color: var(--cyan); margin: 16px 0 6px; }}
  .finding-col h4:first-child {{ margin-top: 0; }}
  .finding-col p {{ font-size: 14px; color: var(--text-dim); }}

  /* BADGE */
  .badge {{ padding: 3px 10px; border-radius: 4px; font-size: 11px;
    font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: #fff; }}

  /* CVSS */
  .cvss-bar-wrap {{ display: flex; align-items: center; gap: 10px; margin: 8px 0; }}
  .cvss-bar {{ height: 8px; border-radius: 4px; transition: width 0.3s; }}
  .cvss-score {{ font-size: 20px; font-weight: 800; }}
  .cvss-vector {{ font-family: monospace; font-size: 11px; color: var(--text-dim); }}

  /* REFS */
  .refs {{ display: flex; flex-direction: column; gap: 4px; }}
  .ref-link {{ font-size: 12px; color: var(--cyan); text-decoration: none; word-break: break-all; }}
  .ref-link:hover {{ text-decoration: underline; }}

  /* SCREENSHOTS */
  .screenshot-wrap {{ margin: 16px 0; border: 1px solid var(--border); border-radius: 6px; overflow: hidden; }}
  .screenshot-img {{ width: 100%; display: block; }}

  /* RAW OUTPUT */
  .raw-details {{ margin-top: 16px; }}
  .raw-details summary {{ cursor: pointer; color: var(--text-dim); font-size: 13px; padding: 8px 0; }}
  .raw-output {{ background: #050810; padding: 12px 16px; border-radius: 6px;
    font-size: 12px; color: #6ee7b7; overflow-x: auto; max-height: 300px; overflow-y: auto;
    white-space: pre-wrap; word-break: break-all; margin-top: 8px; }}

  /* FOOTER */
  .footer {{ text-align: center; padding: 30px; color: var(--text-dim); font-size: 13px;
    border-top: 1px solid var(--border); margin-top: 40px; }}
  .footer strong {{ color: var(--cyan); }}

  /* FILTER BAR */
  .filter-bar {{ display: flex; gap: 10px; margin-bottom: 20px; flex-wrap: wrap; }}
  .filter-btn {{ background: var(--bg2); border: 1px solid var(--border); color: var(--text-dim);
    padding: 6px 16px; border-radius: 20px; cursor: pointer; font-size: 13px; }}
  .filter-btn:hover, .filter-btn.active {{ border-color: var(--cyan); color: var(--cyan); }}

  @media(max-width: 768px) {{
    .overview-grid {{ grid-template-columns: 1fr; }}
    .finding-grid {{ grid-template-columns: 1fr; }}
    .main {{ padding: 16px; }}
    .header {{ padding: 16px; flex-direction: column; gap: 16px; }}
  }}
</style>
</head>
<body>

<div class="header">
  <div>
    <div class="header-logo">⚡ GOLDEN<span>AGE</span> RECONKIT</div>
    <div class="header-sub">Penetration Testing Report — Confidential</div>
  </div>
  <div class="risk-badge">RISK: {risk}</div>
</div>

<nav class="nav">
  <a href="#overview">Overview</a>
  <a href="#findings">Findings ({total})</a>
  <a href="#screenshots">Screenshots</a>
  <a href="#raw">Raw Output</a>
</nav>

<div class="main">

  <!-- OVERVIEW -->
  <div id="overview" class="overview-grid">
    <div class="card">
      <h2>📋 Engagement Details</h2>
      <table class="target-info">
        <tr><td>Target</td><td>{self.target}</td></tr>
        <tr><td>Scan Profile</td><td>{self.profile.upper()}</td></tr>
        <tr><td>Date</td><td>{self.ts.strftime("%B %d, %Y  %H:%M:%S")}</td></tr>
        <tr><td>Tools Used</td><td>{', '.join(tools_used)}</td></tr>
        <tr><td>Total Findings</td><td>{total}</td></tr>
        <tr><td>Avg CVSS Score</td><td>{avg_cvss:.2f} / 10.0</td></tr>
        <tr><td>Overall Risk</td><td style="color:{risk_color};font-weight:700">{risk}</td></tr>
        <tr><td>Prepared By</td><td>{config.AUTHOR}</td></tr>
        <tr><td>Contact</td><td>{config.CONTACT}</td></tr>
      </table>
    </div>
    <div class="card">
      <h2>⚠ Severity Breakdown</h2>
      {stat_cards}
      <div style="margin-top:16px;font-size:12px;color:var(--text-dim)">
        ⚠ This report is confidential. Do not distribute without authorization.
      </div>
    </div>
  </div>

  <!-- STATS -->
  <div class="stats-row">
    <div class="stat-card" style="border-top:3px solid var(--cyan)">
      <div class="stat-num" style="color:var(--cyan)">{total}</div>
      <div class="stat-label">Total Findings</div>
    </div>
    <div class="stat-card" style="border-top:3px solid {risk_color}">
      <div class="stat-num" style="color:{risk_color}">{avg_cvss:.1f}</div>
      <div class="stat-label">Avg CVSS</div>
    </div>
    <div class="stat-card" style="border-top:3px solid var(--purple)">
      <div class="stat-num" style="color:var(--purple)">{len(tools_used)}</div>
      <div class="stat-label">Tools Run</div>
    </div>
  </div>

  <!-- FINDINGS -->
  <div id="findings">
    <div class="section-title">🔍 Findings</div>

    <div class="filter-bar">
      <button class="filter-btn active" onclick="filterFindings('all')">All</button>
      <button class="filter-btn" onclick="filterFindings('critical')" style="color:#ff0000;border-color:#ff000044">Critical</button>
      <button class="filter-btn" onclick="filterFindings('high')" style="color:#ff6b35;border-color:#ff6b3544">High</button>
      <button class="filter-btn" onclick="filterFindings('medium')" style="color:#ffaa00;border-color:#ffaa0044">Medium</button>
      <button class="filter-btn" onclick="filterFindings('low')" style="color:#00d4ff;border-color:#00d4ff44">Low</button>
      <button class="filter-btn" onclick="filterFindings('info')">Info</button>
    </div>

    {finding_cards}
  </div>

</div>

<div class="footer">
  <strong>GoldenAge Cybersecurity Consultancy</strong> — {config.CONTACT}<br>
  Report generated: {self.ts.strftime("%Y-%m-%d %H:%M:%S")} — ReconKit v{config.VERSION}<br>
  <em style="font-size:11px">This report contains confidential information. Unauthorized distribution is prohibited.</em>
</div>

<script>
function filterFindings(severity) {{
  document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
  event.target.classList.add('active');
  document.querySelectorAll('.finding-card').forEach(card => {{
    if (severity === 'all') {{
      card.style.display = '';
    }} else {{
      const badge = card.querySelector('.badge');
      if (badge && badge.textContent.toLowerCase() === severity) {{
        card.style.display = '';
      }} else {{
        card.style.display = 'none';
      }}
    }}
  }});
}}
</script>

</body>
</html>"""

        with open(output_path, "w", encoding="utf-8") as f:
            f.write(html)

        return output_path

RECONEOF

cat > reporter/pdf_reporter.py << 'RECONEOF'
import os
from datetime import datetime
from collections import Counter
import config

class PDFReporter:
    """Generates a PDF pentest report using ReportLab (cross-platform)."""

    def __init__(self, target, profile, findings):
        self.target = target
        self.profile = profile
        self.findings = findings
        self.ts = datetime.now()

    def generate(self, output_path=None):
        try:
            from reportlab.lib.pagesizes import A4
            from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
            from reportlab.lib.colors import HexColor, white, black
            from reportlab.lib.units import mm
            from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table,
                                            TableStyle, HRFlowable, PageBreak)
            from reportlab.lib.enums import TA_CENTER, TA_LEFT
        except ImportError:
            print("[!] ReportLab not installed. Run: pip install reportlab --break-system-packages")
            return ""

        if not output_path:
            ts = self.ts.strftime("%Y%m%d_%H%M%S")
            safe_target = self.target.replace("/", "-").replace(":", "-")
            output_path = os.path.join(config.REPORTS_DIR, f"goldenage_report_{safe_target}_{ts}.pdf")

        doc = SimpleDocTemplate(output_path, pagesize=A4,
                                rightMargin=20*mm, leftMargin=20*mm,
                                topMargin=20*mm, bottomMargin=20*mm)

        # Colors
        C_BG       = HexColor("#0a0e1a")
        C_CYAN     = HexColor("#00d4ff")
        C_ORANGE   = HexColor("#ff6b35")
        C_PURPLE   = HexColor("#7b2ff7")
        C_DARK     = HexColor("#0f1629")
        C_BORDER   = HexColor("#1e2d4a")
        C_TEXT     = HexColor("#e0e6f0")
        C_DIM      = HexColor("#8892a4")
        SEV_COLORS = {
            "Critical": HexColor("#ff0000"),
            "High":     HexColor("#ff6b35"),
            "Medium":   HexColor("#ffaa00"),
            "Low":      HexColor("#00d4ff"),
            "Info":     HexColor("#888888"),
        }

        styles = getSampleStyleSheet()

        def make_style(name, **kwargs):
            return ParagraphStyle(name=name, **kwargs)

        style_h1 = make_style("H1", fontSize=22, textColor=C_CYAN, spaceAfter=6, fontName="Helvetica-Bold", alignment=TA_CENTER)
        style_h2 = make_style("H2", fontSize=14, textColor=C_CYAN, spaceAfter=4, fontName="Helvetica-Bold")
        style_h3 = make_style("H3", fontSize=11, textColor=C_ORANGE, spaceAfter=3, fontName="Helvetica-Bold")
        style_body = make_style("Body", fontSize=9, textColor=C_TEXT, spaceAfter=3, fontName="Helvetica")
        style_dim = make_style("Dim", fontSize=8, textColor=C_DIM, spaceAfter=2, fontName="Helvetica")
        style_code = make_style("Code", fontSize=7, textColor=HexColor("#6ee7b7"),
                                backColor=HexColor("#050810"), fontName="Courier", spaceAfter=4)
        style_center = make_style("Center", fontSize=9, textColor=C_TEXT, alignment=TA_CENTER)

        severity_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Info": 4}
        sorted_findings = sorted(self.findings, key=lambda f: severity_order.get(f.severity, 5))
        counts = Counter(f.severity for f in self.findings)
        total = len(self.findings)
        avg_cvss = sum(f.cvss_score for f in self.findings) / total if total else 0
        tools_used = list(set(f.tool for f in self.findings))
        risk = "CRITICAL" if counts.get("Critical", 0) > 0 else \
               "HIGH"     if counts.get("High", 0) > 0     else \
               "MEDIUM"   if counts.get("Medium", 0) > 0   else "LOW"

        story = []

        # ── Cover ────────────────────────────────────────────────────────────
        story.append(Spacer(1, 30*mm))
        story.append(Paragraph("⚡ GoldenAge ReconKit", style_h1))
        story.append(Paragraph("Penetration Testing Report", make_style("sub", fontSize=14,
            textColor=C_DIM, alignment=TA_CENTER, spaceAfter=4)))
        story.append(HRFlowable(width="80%", color=C_CYAN, thickness=1, spaceAfter=16))
        story.append(Spacer(1, 10*mm))

        cover_data = [
            ["Target",       self.target],
            ["Scan Profile", self.profile.upper()],
            ["Date",         self.ts.strftime("%B %d, %Y  %H:%M:%S")],
            ["Overall Risk", risk],
            ["Avg CVSS",     f"{avg_cvss:.2f} / 10.0"],
            ["Prepared By",  config.AUTHOR],
            ["Contact",      config.CONTACT],
        ]
        cover_table = Table(cover_data, colWidths=[60*mm, 110*mm])
        cover_table.setStyle(TableStyle([
            ("BACKGROUND",  (0,0), (0,-1), C_DARK),
            ("TEXTCOLOR",   (0,0), (0,-1), C_CYAN),
            ("TEXTCOLOR",   (1,0), (1,-1), C_TEXT),
            ("FONTNAME",    (0,0), (0,-1), "Helvetica-Bold"),
            ("FONTSIZE",    (0,0), (-1,-1), 9),
            ("ROWBACKGROUNDS", (0,0), (-1,-1), [C_DARK, HexColor("#111827")]),
            ("GRID",        (0,0), (-1,-1), 0.3, C_BORDER),
            ("TOPPADDING",  (0,0), (-1,-1), 6),
            ("BOTTOMPADDING",(0,0),(-1,-1), 6),
            ("LEFTPADDING", (0,0), (-1,-1), 8),
        ]))
        story.append(cover_table)
        story.append(PageBreak())

        # ── Summary ───────────────────────────────────────────────────────────
        story.append(Paragraph("Executive Summary", style_h2))
        story.append(HRFlowable(width="100%", color=C_BORDER, thickness=0.5, spaceAfter=8))

        sev_data = [["Severity", "Count", "Description"]]
        sev_descs = {
            "Critical": "Immediate action required — exploitable without auth",
            "High":     "High risk — should be patched within days",
            "Medium":   "Moderate risk — patch within 30 days",
            "Low":      "Low risk — patch in next maintenance window",
            "Info":     "Informational — no immediate action required",
        }
        for sev in ["Critical","High","Medium","Low","Info"]:
            sev_data.append([sev, str(counts.get(sev, 0)), sev_descs[sev]])

        sev_table = Table(sev_data, colWidths=[40*mm, 25*mm, 105*mm])
        sev_style = [
            ("BACKGROUND",  (0,0), (-1,0), C_DARK),
            ("TEXTCOLOR",   (0,0), (-1,0), C_CYAN),
            ("FONTNAME",    (0,0), (-1,0), "Helvetica-Bold"),
            ("FONTSIZE",    (0,0), (-1,-1), 8),
            ("GRID",        (0,0), (-1,-1), 0.3, C_BORDER),
            ("ROWBACKGROUNDS", (0,1), (-1,-1), [C_DARK, HexColor("#111827")]),
            ("TOPPADDING",  (0,0), (-1,-1), 5),
            ("BOTTOMPADDING",(0,0),(-1,-1), 5),
            ("LEFTPADDING", (0,0), (-1,-1), 8),
        ]
        for i, sev in enumerate(["Critical","High","Medium","Low","Info"], 1):
            c = SEV_COLORS.get(sev, HexColor("#888"))
            sev_style.append(("TEXTCOLOR", (0,i), (0,i), c))
            sev_style.append(("FONTNAME",  (0,i), (0,i), "Helvetica-Bold"))
            sev_style.append(("TEXTCOLOR", (1,i), (1,i), c))
            sev_style.append(("FONTNAME",  (1,i), (1,i), "Helvetica-Bold"))
        sev_table.setStyle(TableStyle(sev_style))
        story.append(sev_table)
        story.append(Spacer(1, 8*mm))

        story.append(Paragraph(
            f"This assessment of <b>{self.target}</b> identified <b>{total}</b> findings across "
            f"{len(tools_used)} scanning tools. The overall risk rating is <b>{risk}</b> with an "
            f"average CVSS score of <b>{avg_cvss:.2f}</b>. Immediate remediation is recommended for "
            f"all Critical and High severity findings.",
            make_style("exec", fontSize=9, textColor=C_TEXT, spaceAfter=6, leading=14)
        ))
        story.append(PageBreak())

        # ── Findings ──────────────────────────────────────────────────────────
        story.append(Paragraph(f"Detailed Findings ({total})", style_h2))
        story.append(HRFlowable(width="100%", color=C_BORDER, thickness=0.5, spaceAfter=8))

        for i, f in enumerate(sorted_findings, 1):
            sev_color = SEV_COLORS.get(f.severity, HexColor("#888"))

            story.append(Paragraph(f"Finding #{i}: {f.title}", make_style(
                f"FH{i}", fontSize=11, textColor=sev_color,
                fontName="Helvetica-Bold", spaceAfter=3)))

            meta_data = [
                ["Tool", f.tool.upper(), "Severity", f.severity, "CVSS", str(f.cvss_score)],
            ]
            meta_table = Table(meta_data, colWidths=[20*mm, 30*mm, 20*mm, 25*mm, 15*mm, 60*mm])
            meta_table.setStyle(TableStyle([
                ("BACKGROUND",   (0,0), (-1,0), C_DARK),
                ("TEXTCOLOR",    (0,0), (-1,0), C_DIM),
                ("FONTSIZE",     (0,0), (-1,0), 8),
                ("GRID",         (0,0), (-1,-1), 0.3, C_BORDER),
                ("TOPPADDING",   (0,0), (-1,-1), 4),
                ("BOTTOMPADDING",(0,0), (-1,-1), 4),
                ("LEFTPADDING",  (0,0), (-1,-1), 6),
                ("TEXTCOLOR",    (1,0), (1,0), C_CYAN),
                ("TEXTCOLOR",    (3,0), (3,0), sev_color),
                ("TEXTCOLOR",    (5,0), (5,0), sev_color),
            ]))
            story.append(meta_table)
            story.append(Spacer(1, 3*mm))

            # Description, Impact, Remediation
            detail_data = [
                ["Description", (f.description or "N/A")[:600]],
                ["Impact",      f.impact or "N/A"],
                ["Remediation", (f.remediation or "N/A")],
                ["CVSS Vector", f.cvss_vector or "N/A"],
                ["References",  "\n".join(f.references[:3]) if f.references else "N/A"],
            ]
            detail_table = Table(detail_data, colWidths=[30*mm, 140*mm])
            detail_table.setStyle(TableStyle([
                ("BACKGROUND",   (0,0), (0,-1), C_DARK),
                ("TEXTCOLOR",    (0,0), (0,-1), C_CYAN),
                ("FONTNAME",     (0,0), (0,-1), "Helvetica-Bold"),
                ("TEXTCOLOR",    (1,0), (1,-1), C_TEXT),
                ("FONTSIZE",     (0,0), (-1,-1), 8),
                ("GRID",         (0,0), (-1,-1), 0.3, C_BORDER),
                ("ROWBACKGROUNDS", (0,0), (-1,-1), [C_DARK, HexColor("#111827")]),
                ("TOPPADDING",   (0,0), (-1,-1), 5),
                ("BOTTOMPADDING",(0,0), (-1,-1), 5),
                ("LEFTPADDING",  (0,0), (-1,-1), 8),
                ("VALIGN",       (0,0), (-1,-1), "TOP"),
            ]))
            story.append(detail_table)
            story.append(Spacer(1, 6*mm))

            if i < len(sorted_findings) and i % 3 == 0:
                story.append(PageBreak())

        # ── Footer page ───────────────────────────────────────────────────────
        story.append(PageBreak())
        story.append(Spacer(1, 40*mm))
        story.append(Paragraph("GoldenAge Cybersecurity Consultancy", style_h1))
        story.append(Paragraph(config.CONTACT, make_style("foot", fontSize=11,
            textColor=C_DIM, alignment=TA_CENTER, spaceAfter=4)))
        story.append(Paragraph(
            "This report is strictly confidential. Unauthorized reproduction or distribution is prohibited.",
            make_style("disc", fontSize=8, textColor=C_DIM, alignment=TA_CENTER)))

        doc.build(story)
        return output_path

RECONEOF

cat > reporter/log_reporter.py << 'RECONEOF'
"""
GoldenAge ReconKit — Pretty Text Log Reporter
Generates a human-readable, well-formatted .txt log of the entire scan session.
Opens cleanly on Windows (Notepad/VS Code), macOS (TextEdit), and Linux (any editor/cat).
"""

import os
from datetime import datetime
from collections import Counter
import config


class LogReporter:
    def __init__(self, target, profile, findings, module_log=None, elapsed=0.0):
        self.target = target
        self.profile = profile
        self.findings = findings
        self.module_log = module_log or []   # list of {module, status, count, duration, error}
        self.elapsed = elapsed
        self.ts = datetime.now()

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _line(self, char="─", width=80):
        return char * width

    def _box(self, title, char="═", width=80):
        inner = f"  {title}  "
        pad = (width - len(inner) - 2)
        left = pad // 2
        right = pad - left
        top = f"╔{'═' * (width - 2)}╗"
        mid = f"║{' ' * left}{inner}{' ' * right}║"
        bot = f"╚{'═' * (width - 2)}╝"
        return f"{top}\n{mid}\n{bot}"

    def _section(self, title, width=80):
        bar = "▓" * 3
        return f"\n{bar} {title.upper()} {bar}\n{self._line('─', width)}"

    def _severity_label(self, sev):
        icons = {
            "Critical": "🔴 CRITICAL",
            "High":     "🟠 HIGH    ",
            "Medium":   "🟡 MEDIUM  ",
            "Low":      "🔵 LOW     ",
            "Info":     "⚪ INFO    ",
        }
        return icons.get(sev, f"   {sev:9}")

    def _severity_bar(self, count, max_count, width=20):
        if max_count == 0:
            return "░" * width
        filled = int((count / max_count) * width)
        return "█" * filled + "░" * (width - filled)

    # ── Sections ──────────────────────────────────────────────────────────────

    def _header(self):
        lines = [
            "",
            self._line("═"),
            "",
            "   ██████╗  ██████╗ ██╗     ██████╗ ███████╗███╗   ██╗ █████╗  ██████╗ ███████╗",
            "  ██╔════╝ ██╔═══██╗██║     ██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔════╝ ██╔════╝",
            "  ██║  ███╗██║   ██║██║     ██║  ██║█████╗  ██╔██╗ ██║███████║██║  ███╗█████╗  ",
            "  ██║   ██║██║   ██║██║     ██║  ██║██╔══╝  ██║╚██╗██║██╔══██║██║   ██║██╔══╝  ",
            "  ╚██████╔╝╚██████╔╝███████╗██████╔╝███████╗██║ ╚████║██║  ██║╚██████╔╝███████╗",
            "   ╚═════╝  ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝",
            "",
            f"  {'RECONKIT — SCAN LOG':^76}",
            f"  {'v' + config.VERSION:^76}",
            "",
            self._line("═"),
        ]
        return "\n".join(lines)

    def _meta(self):
        counts = Counter(f.severity for f in self.findings)
        total = len(self.findings)
        avg_cvss = sum(f.cvss_score for f in self.findings) / total if total else 0
        risk = ("CRITICAL" if counts.get("Critical", 0) > 0 else
                "HIGH"     if counts.get("High", 0)     > 0 else
                "MEDIUM"   if counts.get("Medium", 0)   > 0 else "LOW")

        lines = [
            self._section("ENGAGEMENT DETAILS"),
            "",
            f"  {'Target':<22} {self.target}",
            f"  {'Scan Profile':<22} {self.profile.upper()}",
            f"  {'Date & Time':<22} {self.ts.strftime('%B %d, %Y   %H:%M:%S')}",
            f"  {'Scan Duration':<22} {self.elapsed:.1f} seconds",
            f"  {'Total Findings':<22} {total}",
            f"  {'Average CVSS':<22} {avg_cvss:.2f} / 10.0",
            f"  {'Overall Risk':<22} *** {risk} ***",
            f"  {'Prepared By':<22} {config.AUTHOR}",
            f"  {'Contact':<22} {config.CONTACT}",
            "",
        ]
        return "\n".join(lines)

    def _severity_breakdown(self):
        counts = Counter(f.severity for f in self.findings)
        max_count = max(counts.values()) if counts else 1
        lines = [
            self._section("SEVERITY BREAKDOWN"),
            "",
        ]
        for sev in ["Critical", "High", "Medium", "Low", "Info"]:
            c = counts.get(sev, 0)
            bar = self._severity_bar(c, max_count)
            lines.append(f"  {self._severity_label(sev)}  {bar}  {c:>3} finding(s)")
        lines.append("")
        return "\n".join(lines)

    def _module_summary(self):
        if not self.module_log:
            return ""
        lines = [
            self._section("MODULE EXECUTION LOG"),
            "",
            f"  {'Module':<18} {'Status':<12} {'Findings':<12} {'Duration':<12} Notes",
            f"  {self._line('-', 76)}",
        ]
        for entry in self.module_log:
            status_icon = "✓" if entry.get("status") == "ok" else "✗" if entry.get("status") == "error" else "⚠"
            lines.append(
                f"  {entry['module']:<18} "
                f"[{status_icon}] {entry.get('status','?'):<9} "
                f"{entry.get('count',0):<12} "
                f"{entry.get('duration','N/A'):<12} "
                f"{entry.get('notes','')}"
            )
        lines.append("")
        return "\n".join(lines)

    def _findings_detail(self):
        if not self.findings:
            return self._section("FINDINGS") + "\n\n  No findings recorded.\n"

        severity_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Info": 4}
        sorted_f = sorted(self.findings, key=lambda f: severity_order.get(f.severity, 5))

        lines = [self._section("DETAILED FINDINGS"), ""]

        for i, f in enumerate(sorted_f, 1):
            sev_label = self._severity_label(f.severity)
            lines += [
                f"  ┌{'─' * 76}┐",
                f"  │  Finding #{i:<4}  {sev_label}   CVSS: {f.cvss_score:.1f}/10.0{' ' * (26 - len(str(f.cvss_score)))  }│",
                f"  ├{'─' * 76}┤",
                f"  │  Tool       : {f.tool.upper():<60}│",
                f"  │  Title      : {f.title[:60]:<60}│",
                f"  │  Type       : {f.finding_type:<60}│",
                f"  │  Timestamp  : {f.timestamp[:19].replace('T',' '):<60}│",
                f"  ├{'─' * 76}┤",
            ]

            # Description — wrap at 60 chars
            desc_lines = self._wrap(f.description or "N/A", 60)
            lines.append(f"  │  DESCRIPTION:{' ' * 62}│")
            for dl in desc_lines:
                lines.append(f"  │    {dl:<72}│")

            lines.append(f"  │{' ' * 76}│")

            # Impact
            lines.append(f"  │  IMPACT:{' ' * 67}│")
            for il in self._wrap(f.impact or "N/A", 60):
                lines.append(f"  │    {il:<72}│")

            lines.append(f"  │{' ' * 76}│")

            # Remediation
            lines.append(f"  │  REMEDIATION:{' ' * 62}│")
            for rl in self._wrap(f.remediation or "N/A", 60):
                lines.append(f"  │    {rl:<72}│")

            lines.append(f"  │{' ' * 76}│")

            # CVSS
            lines.append(f"  │  CVSS VECTOR : {(f.cvss_vector or 'N/A')[:59]:<60}│")

            # References
            lines.append(f"  │  REFERENCES  :{' ' * 62}│")
            for ref in (f.references or [])[:4]:
                for rline in self._wrap(ref, 68):
                    lines.append(f"  │    {rline:<72}│")

            lines += [
                f"  └{'─' * 76}┘",
                "",
            ]

        return "\n".join(lines)

    def _raw_outputs_section(self):
        # Collect raw outputs from findings (deduplicated)
        seen = set()
        sections = [self._section("RAW TOOL OUTPUTS (SUMMARY)"), ""]
        for f in self.findings:
            key = f"{f.tool}_{f.finding_type}"
            if key in seen or not f.raw_output:
                continue
            seen.add(key)
            sections.append(f"  ── {f.tool.upper()} ──────────────────────────────")
            for line in f.raw_output[:800].splitlines():
                sections.append(f"  {line}")
            sections.append("")
        return "\n".join(sections)

    def _footer(self):
        lines = [
            self._line("═"),
            "",
            f"  {'GoldenAge Cybersecurity Consultancy':^76}",
            f"  {config.CONTACT:^76}",
            "",
            f"  {'CERTIFICATIONS: CEH | CPent | CHFI | ECIH | CISSP | ISO 27001':^76}",
            "",
            f"  {'⚠  CONFIDENTIAL — Unauthorized distribution is prohibited  ⚠':^76}",
            "",
            f"  {'Generated: ' + self.ts.strftime('%Y-%m-%d %H:%M:%S') + '  |  ReconKit v' + config.VERSION:^76}",
            "",
            self._line("═"),
            "",
        ]
        return "\n".join(lines)

    # ── Wrap helper ───────────────────────────────────────────────────────────

    def _wrap(self, text, width):
        """Simple word-wrap."""
        text = text.replace("\n", " ").replace("**", "").replace("`", "")
        words = text.split()
        lines = []
        current = ""
        for word in words:
            if len(current) + len(word) + 1 <= width:
                current = f"{current} {word}".strip()
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
        return lines or [""]

    # ── Generate ──────────────────────────────────────────────────────────────

    def generate(self, output_path=None):
        if not output_path:
            ts = self.ts.strftime("%Y%m%d_%H%M%S")
            safe = self.target.replace("/", "-").replace(":", "-")
            output_path = os.path.join(config.LOGS_DIR, f"reconkit_log_{safe}_{ts}.txt")

        content = "\n".join([
            self._header(),
            self._meta(),
            self._severity_breakdown(),
            self._module_summary(),
            self._findings_detail(),
            self._raw_outputs_section(),
            self._footer(),
        ])

        with open(output_path, "w", encoding="utf-8") as f:
            f.write(content)

        return output_path

RECONEOF

cat > utils/__init__.py << 'RECONEOF'
from .banner import print_banner
from .logger import setup_logger

RECONEOF

cat > utils/banner.py << 'RECONEOF'
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
import config

console = Console()

BANNER = r"""
  ██████╗  ██████╗ ██╗     ██████╗ ███████╗███╗   ██╗ █████╗  ██████╗ ███████╗
 ██╔════╝ ██╔═══██╗██║     ██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔════╝ ██╔════╝
 ██║  ███╗██║   ██║██║     ██║  ██║█████╗  ██╔██╗ ██║███████║██║  ███╗█████╗  
 ██║   ██║██║   ██║██║     ██║  ██║██╔══╝  ██║╚██╗██║██╔══██║██║   ██║██╔══╝  
 ╚██████╔╝╚██████╔╝███████╗██████╔╝███████╗██║ ╚████║██║  ██║╚██████╔╝███████╗
  ╚═════╝  ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
"""

def print_banner():
    console.print(f"[bold cyan]{BANNER}[/bold cyan]")
    console.print(Panel.fit(
        f"[bold cyan]  ⚡ ReconKit v{config.VERSION}  [/bold cyan][dim]│[/dim]  "
        f"[yellow]{config.AUTHOR}[/yellow]  [dim]│[/dim]  "
        f"[dim]{config.CONTACT}[/dim]",
        border_style="cyan"
    ))
    console.print()

RECONEOF

cat > utils/logger.py << 'RECONEOF'
import logging
import os
from datetime import datetime
import config

def setup_logger(name="reconkit"):
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    if not logger.handlers:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        fh = logging.FileHandler(os.path.join(config.LOGS_DIR, f"reconkit_{ts}.log"))
        fh.setLevel(logging.DEBUG)
        fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
        fh.setFormatter(fmt)
        logger.addHandler(fh)
    return logger

RECONEOF

cat > Dockerfile << 'RECONEOF'
# ─────────────────────────────────────────────────────────────────────────────
#  GoldenAge ReconKit — Docker Image
#  Base: Kali Linux (all pentest tools pre-installed)
#  Usage: docker run -it --rm -v $(pwd)/output:/app/output goldenage/reconkit
# ─────────────────────────────────────────────────────────────────────────────

FROM kalilinux/kali-rolling

LABEL maintainer="GoldenAge Cybersecurity Consultancy <info@goldenage-consultancy.com>"
LABEL description="GoldenAge ReconKit — Unified Penetration Testing Framework"
LABEL version="1.0.0"

# ── Avoid interactive prompts during apt installs ─────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# ── Install all pentest tools + Python + system deps ─────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core tools
    nmap \
    nikto \
    gobuster \
    hydra \
    whatweb \
    sqlmap \
    feroxbuster \
    # Python
    python3 \
    python3-pip \
    python3-dev \
    # Wordlists
    wordlists \
    seclists \
    # Browser screenshot deps (Playwright/Chromium)
    chromium \
    chromium-driver \
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    # Fonts for terminal screenshots
    fonts-dejavu-core \
    fonts-liberation \
    # Utilities
    wget \
    curl \
    git \
    unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Extract rockyou wordlist ──────────────────────────────────────────────────
RUN gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null || true

# ── Set working directory ─────────────────────────────────────────────────────
WORKDIR /app

# ── Copy project files ────────────────────────────────────────────────────────
COPY requirements.txt .

# ── Install Python dependencies ───────────────────────────────────────────────
RUN pip3 install --no-cache-dir --break-system-packages \
    rich \
    requests \
    reportlab \
    Pillow \
    playwright

# ── Install Playwright Chromium browser ───────────────────────────────────────
RUN python3 -m playwright install chromium 2>/dev/null || true
RUN python3 -m playwright install-deps chromium 2>/dev/null || true

# ── Copy rest of the project ──────────────────────────────────────────────────
COPY . .

# ── Create output directories ─────────────────────────────────────────────────
RUN mkdir -p output/reports output/screenshots output/logs

# ── Set permissions ───────────────────────────────────────────────────────────
RUN chmod +x main.py install.sh

# ── Default command ───────────────────────────────────────────────────────────
CMD ["python3", "main.py"]

RECONEOF

cat > docker-compose.yml << 'RECONEOF'
# ─────────────────────────────────────────────────────────────────────────────
#  GoldenAge ReconKit — Docker Compose
#
#  Usage:
#    docker compose run reconkit              # interactive scan
#    docker compose run reconkit --help       # show help
#
#  Output files automatically saved to ./output/ on your host machine
# ─────────────────────────────────────────────────────────────────────────────

version: "3.8"

services:
  reconkit:
    image: goldenage/reconkit:latest
    build:
      context: .
      dockerfile: Dockerfile
    container_name: goldenage-reconkit

    # ── Interactive terminal (required for the CLI menu) ──────────────────────
    stdin_open: true
    tty: true

    # ── Mount output folder so reports save to your host machine ─────────────
    volumes:
      - ./output:/app/output

    # ── Network mode host gives nmap/tools direct access to target network ────
    network_mode: host

    # ── Run as root (required for nmap SYN scans) ─────────────────────────────
    cap_add:
      - NET_ADMIN
      - NET_RAW

    # ── Optional: pre-set OpenCTI / Rudder credentials via environment ────────
    environment:
      - OPENCTI_URL=${OPENCTI_URL:-}
      - OPENCTI_TOKEN=${OPENCTI_TOKEN:-}
      - RUDDER_URL=${RUDDER_URL:-}
      - RUDDER_TOKEN=${RUDDER_TOKEN:-}

    # ── Entry point ───────────────────────────────────────────────────────────
    command: python3 main.py

RECONEOF

cat > install.sh << 'RECONEOF'
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

RECONEOF

cat > LICENSE << 'RECONEOF'
MIT License

Copyright (c) 2025 GoldenAge Cybersecurity Consultancy
https://goldenage-consultancy.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IMPORTANT LEGAL NOTICE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This software is intended exclusively for authorized penetration testing,
security research, and educational purposes.

Using this tool against systems you do not own or do not have explicit written
authorization to test is ILLEGAL and may violate computer fraud and abuse laws
in your jurisdiction, including but not limited to:

  - Computer Fraud and Abuse Act (CFAA) — United States
  - Computer Misuse Act — United Kingdom
  - Bilişim Suçları Kanunu — Turkey
  - NCA 2015 / Saudi Cybercrime Law — Saudi Arabia
  - EU Directive on Attacks Against Information Systems

GoldenAge Cybersecurity Consultancy accepts NO liability for unauthorized,
illegal, or malicious use of this software by any third party.

By using this software you confirm that:
  1. You own the target system, OR
  2. You have explicit written authorization from the system owner
  3. You accept full legal responsibility for your actions

RECONEOF

touch output/reports/.gitkeep output/screenshots/.gitkeep output/logs/.gitkeep
cat > .gitignore << 'RECONEOF'
# Python cache — never commit these
__pycache__/
*.pyc
*.pyo
*.pyd
*.egg-info/

# ReconKit output — contains scan results, never commit
output/reports/*
output/screenshots/*
output/logs/*

# Keep the output folder structure but not the contents
!output/reports/.gitkeep
!output/screenshots/.gitkeep
!output/logs/.gitkeep

# Environment / credentials — NEVER commit
.env
*.env

# OS files
.DS_Store
Thumbs.db
desktop.ini

# IDE
.vscode/
.idea/
*.swp
*.swo

# Zip files
*.zip

RECONEOF

cat > .dockerignore << 'RECONEOF'
# Python cache
__pycache__/
*.pyc
*.pyo
*.pyd
*.egg-info/

# Output — don't bake reports into the image
output/reports/*
output/screenshots/*
output/logs/*

# Git
.git/
.gitignore

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/

# Zip files
*.zip

RECONEOF


chmod +x main.py install.sh

echo ""
echo "✅ All files created successfully!"
echo ""
echo "📁 Project is at: /home/kali/goldenage-reconkit"
ls
echo ""
echo "🐳 Now building Docker image (takes 5-10 min)..."
docker build -t goldenage/reconkit .
echo ""
echo "🚀 Done! Run with: docker compose run reconkit"
