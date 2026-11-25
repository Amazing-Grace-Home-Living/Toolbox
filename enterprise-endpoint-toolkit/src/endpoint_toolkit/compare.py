"""Compare two local endpoint inventory exports without changing any devices."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from .core import analyze_devices

# Unknown is not healthy. Escalate newly unknown data for investigation.
_SEVERITY = {"low": 0, "medium": 1, "unknown": 2, "high": 3}


def _indexed(rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        identifier = row["id"].strip()
        if identifier:
            key = "id:" + identifier
        elif row["name"] != "Unnamed":
            key = "device:" + row["name"].casefold() + "|" + row["platform"].casefold()
        else:
            raise ValueError("every device needs an id or a non-empty name to compare")
        if key in result:
            raise ValueError("duplicate device identifier in inventory: " + key)
        result[key] = row
    return result


def compare_inventories(
    before: list[dict[str, Any]],
    after: list[dict[str, Any]],
    *,
    stale_days: int = 30,
    now: datetime | None = None,
) -> dict[str, Any]:
    """Return device-level drift and counts; unknown does not count as compliant."""
    comparison_time = now or datetime.now(timezone.utc)
    previous = _indexed(analyze_devices(before, stale_days=stale_days, now=comparison_time))
    current = _indexed(analyze_devices(after, stale_days=stale_days, now=comparison_time))
    entries: list[dict[str, Any]] = []
    for key in sorted(previous.keys() | current.keys()):
        old = previous.get(key)
        new = current.get(key)
        if old is None:
            change = "added"
        elif new is None:
            change = "missing"
        elif (old["risk"], old["compliance"], old["freshness"], old["platform"]) == (
            new["risk"], new["compliance"], new["freshness"], new["platform"]
        ):
            change = "unchanged"
        elif _SEVERITY[new["risk"]] > _SEVERITY[old["risk"]]:
            change = "regressed"
        elif _SEVERITY[new["risk"]] < _SEVERITY[old["risk"]]:
            # Missing data is not evidence that an earlier problem was resolved.
            change = "changed" if "unknown" in (new["compliance"], new["freshness"]) else "improved"
        else:
            change = "changed"
        entries.append(
            {
                "key": key,
                "name": (new or old)["name"],
                "change": change,
                "previous_risk": old["risk"] if old else None,
                "current_risk": new["risk"] if new else None,
                "previous_compliance": old["compliance"] if old else None,
                "current_compliance": new["compliance"] if new else None,
            }
        )
    counts = {status: sum(row["change"] == status for row in entries) for status in
              ("added", "missing", "regressed", "improved", "changed", "unchanged")}
    return {
        "before_total": len(previous),
        "after_total": len(current),
        "counts": counts,
        "changes": entries,
        "warning": (
            "Missing devices require independent investigation: removal from an "
            "inventory does not prove retirement or remediation. Unknown is not healthy."
        ),
    }
