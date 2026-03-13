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
