# Enterprise Endpoint Automation Toolkit

**Python + PowerShell · Microsoft Intune · Workspace ONE UEM · Read-only compliance analysis**

A working endpoint-engineering portfolio project: normalize device exports, identify stale check-ins and compliance risks, compare inventories over time, and produce audit-ready local reports. No cloud account or API token is required to try it.

[Start here: full toolkit guide](enterprise-endpoint-toolkit/README.md) · [Python CLI](enterprise-endpoint-toolkit/src/endpoint_toolkit/cli.py) · [PowerShell audit module](enterprise-endpoint-toolkit/powershell/EndpointToolkit.psm1) · [CI workflow](.github/workflows/endpoint-toolkit-ci.yml)

## What it does

| Capability | Python | PowerShell |
| --- | :---: | :---: |
| Offline inventory assessment from JSON export | ✅ | ✅ |
| Intune / Workspace ONE field normalization | ✅ | ✅ |
| Separate compliance and stale-check-in checks | ✅ | ✅ |
| Safe handling of unknown/incomplete records | ✅ | ✅ |
| JSON and CSV reports | ✅ | ✅ |
| Self-contained HTML dashboard | ✅ | — |
| Baseline comparison: new/missing/regressed devices | ✅ | — |
| Optional read-only Graph and Workspace ONE API inventory | ✅ | — |
| Unit/regression tests | unittest | Pester |

## Try it — no credentials or hosted services

Python 3.11+:

```bash
# From the repository root, no installation required:
python toolbox/toolbox.py demo --out reports
python toolbox/toolbox.py analyze --input enterprise-endpoint-toolkit/examples/devices.json --out reports

# Compare two local inventory snapshots:
python toolbox/toolbox.py compare --baseline before.json --current after.json --out reports

# Run tests against the actual package:
python -m pip install ./enterprise-endpoint-toolkit
python -m unittest discover -s enterprise-endpoint-toolkit/tests -v
```

PowerShell 7+:

```powershell
pwsh -File ./toolbox/toolbox.ps1 -OutDirectory ./reports
pwsh -File ./toolbox/toolbox.ps1 -InputPath ./enterprise-endpoint-toolkit/examples/devices.json -StaleDays 14

# Unit tests (requires Pester 5):
Invoke-Pester ./enterprise-endpoint-toolkit/tests/EndpointToolkit.Tests.ps1 -CI
```

The tools write `report.json` and `inventory.csv` locally; the Python CLI also writes `dashboard.html`. Comparison writes `drift.json`. The sample inventory uses fictitious lab devices.

### Understanding risk results

- **High:** explicitly noncompliant.
- **Medium:** check-in older than the configured threshold (default 30 days).
- **Unknown:** missing, malformed, or future check-in data, or unknown compliance status.
- **Low:** compliant with a recent check-in.
- **Missing from new export:** investigate; it does **not** prove that a device was retired or remediated.

Risk is a review aid, **not a tenant policy engine**. No device updates, directory changes, or remote execution are performed.

## For enterprise environments

`enterprise-endpoint-toolkit/src/endpoint_toolkit/api.py` contains read-only connectors for Microsoft Graph managedDevices and Workspace ONE UEM device search. Existing, short-lived, appropriately scoped access tokens must be supplied by the operator; the CLI never performs interactive authentication. Workspace ONE result pagination is tenant-specific and is intentionally rejected when incomplete results can be detected.

Review [architecture, security boundaries and limitations](enterprise-endpoint-toolkit/docs/ARCHITECTURE.md) before using live data.

**Privacy:** Never commit access tokens, names/IDs from production device inventories, or generated reports to this public repository. Reports are generated locally by default.

## Additional learning samples

The `arcade/` and other `toolbox/` language files remain as standalone educational examples in Go, Ruby, Java, C#, JavaScript and TypeScript. They are **not** the main portfolio feature. The Python and PowerShell `toolbox` entry points now run the real endpoint auditing tools rather than reversing `hello world`.

---

Built to demonstrate practical endpoint compliance reporting, repeatable tests and explicit security boundaries.
