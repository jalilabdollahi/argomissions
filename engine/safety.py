#!/usr/bin/env python3
"""Safety checks for kubectl and argocd commands typed inside the game."""

from __future__ import annotations

import re

from rich.console import Console
from rich.panel import Panel
from rich.prompt import Confirm

console = Console()

INFRA_NAMESPACES = r"(kube-system|kube-public|kube-node-lease|default|argocd|gitea|local-path-storage)"

KUBECTL_RULES = [
    (rf"kubectl\s+delete\s+(ns|namespaces?)\s+{INFRA_NAMESPACES}(\s|$)",
     "BLOCKED: that namespace runs the game itself (Argo CD, Gitea or Kubernetes).", "critical"),
    (r"kubectl\s+delete\s+nodes?(\s|$)", "BLOCKED: deleting nodes is not allowed.", "critical"),
    (r"kubectl\s+delete\s+(crd|crds|customresourcedefinitions?)(\s|$|\.)", "BLOCKED: deleting CRDs is not allowed.", "critical"),
    (r"kubectl\s+delete\s+.*(\s--all-namespaces|\s-A(\s|$))", "BLOCKED: cluster-wide deletions are not allowed.", "critical"),
    (r"kubectl\s+.*(--context|--kubeconfig|--cluster|--server|-s)(=|\s)",
     "BLOCKED: ArgoMissions commands must run against the ArgoMissions cluster only.", "critical"),
    (r"kubectl\s+.*\s-n\s+argocd\s+.*delete\s+(deploy|deployment|statefulset|sts|svc|service)",
     "Warning: deleting Argo CD's own components breaks the game until the next reset.", "warning"),
    (r"kubectl\s+delete\s+\S+\s+--all(\s|$)", "Warning: this deletes every resource of that type in the namespace.", "warning"),
]

ARGOCD_RULES = [
    (r"argocd\s+(login|relogin)\s+(?!localhost:\d+)",
     "BLOCKED: the game's argocd CLI only talks to the game's Argo CD (localhost).", "critical"),
    (r"argocd\s+.*(--config|--server|--kube-context|--core)(=|\s|$)",
     "BLOCKED: the game sets the argocd server and config for you.", "critical"),
    (r"argocd\s+context(\s|$)", "BLOCKED: the game uses its own argocd context.", "critical"),
    (r"argocd\s+cluster\s+(rm|remove)\s+.*(in-cluster|kubernetes\.default\.svc)",
     "Warning: removing the in-cluster destination breaks most missions until the next reset.", "warning"),
    (r"argocd\s+(app|appset)\s+delete\s+.*--cascade(=true)?(\s|$)",
     "Warning: a cascading delete removes everything the Application deployed.", "warning"),
]


def _check(command: str, rules: list[tuple[str, str, str]]) -> tuple[bool, str, str]:
    for pattern, message, severity in rules:
        if re.search(pattern, command, re.IGNORECASE):
            return False, message, severity
    return True, "", "safe"


def _decide(command: str, rules: list[tuple[str, str, str]], interactive: bool) -> bool:
    ok, message, severity = _check(command, rules)
    if ok:
        return True
    if severity == "critical":
        console.print(Panel(f"[bold red]{message}[/bold red]\n\n[dim]Stay inside the training environment.[/dim]",
                            title="[bold red]Safety Guard[/bold red]", border_style="red"))
        return False
    if not interactive:
        return True
    console.print(Panel(f"[bold yellow]{message}[/bold yellow]", title="[bold yellow]Caution[/bold yellow]",
                        border_style="yellow"))
    return Confirm.ask("Run this command?", default=False)


def validate_kubectl_command(command: str, interactive: bool = True) -> bool:
    return _decide(command.strip(), KUBECTL_RULES, interactive)


def validate_argocd_command(command: str, interactive: bool = True) -> bool:
    return _decide(command.strip(), ARGOCD_RULES, interactive)


def print_safety_info() -> None:
    console.print(Panel(
        "Blocked: deleting the argocd / gitea / system namespaces, nodes, CRDs, cluster-wide deletes,\n"
        "pointing kubectl or argocd at another cluster or config.\n"
        "Warned: deleting Argo CD components, --all deletes, cascading app deletes.\n"
        "Your second terminal is safe too once you `source ./env.sh`: it only knows the game cluster.",
        title="[bold bright_cyan]ArgoMissions Safety[/bold bright_cyan]", border_style="bright_cyan"))
