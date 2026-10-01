#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ASSETS = {
    "MerlinAU-install.sh": "install",
    "MerlinAU-update.sh": "update",
}

OUTPUT_PATH = Path("metrics/release_downloads.csv")

FIELDNAMES = [
    "snapshot_date",
    "snapshot_time_utc",
    "tag",
    "published_at",
    "kind",
    "asset_name",
    "asset_id",
    "download_count",
]


def github_get(url: str, token: str | None):
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "MerlinAU-release-metrics",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = Request(url, headers=headers)

    try:
        with urlopen(request, timeout=30) as response:
            return json.load(response)
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"GitHub API request failed: HTTP {exc.code} for {url}\n{body}"
        ) from exc
    except URLError as exc:
        raise RuntimeError(f"GitHub API request failed for {url}: {exc}") from exc


def get_releases(repository: str, token: str | None) -> list[dict]:
    releases = []
    page = 1

    while True:
        url = (
            f"https://api.github.com/repos/{repository}/releases"
            f"?per_page=100&page={page}"
        )
        payload = github_get(url, token)

        if not isinstance(payload, list):
            raise RuntimeError("Unexpected GitHub API response while listing releases.")

        releases.extend(payload)

        if len(payload) < 100:
            break

        page += 1

    return releases


def load_existing_rows(path: Path):
    rows = {}

    if not path.exists():
        return rows

    with path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)

        missing = [field for field in FIELDNAMES if field not in (reader.fieldnames or [])]
        if missing:
            raise RuntimeError(
                f"{path} is missing expected columns: {', '.join(missing)}"
            )

        for row in reader:
            key = (row["snapshot_date"], row["tag"], row["asset_name"])
            rows[key] = {field: row.get(field, "") for field in FIELDNAMES}

    return rows


def write_rows(path: Path, rows) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")

    ordered_rows = sorted(
        rows.values(),
        key=lambda row: (
            row["snapshot_date"],
            row["published_at"],
            row["tag"],
            row["kind"],
            row["asset_name"],
        ),
    )

    with temp_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(ordered_rows)

    temp_path.replace(path)


def main() -> int:
    repository = os.environ.get("GITHUB_REPOSITORY", "").strip()
    token = os.environ.get("GITHUB_TOKEN", "").strip() or None

    if not repository or "/" not in repository:
        print("ERROR: GITHUB_REPOSITORY must be set to owner/repository.", file=sys.stderr)
        return 1

    now = datetime.now(timezone.utc).replace(microsecond=0)
    snapshot_date = now.date().isoformat()
    snapshot_time = now.isoformat().replace("+00:00", "Z")

    rows = load_existing_rows(OUTPUT_PATH)
    releases = get_releases(repository, token)

    matched_assets = 0

    for release in releases:
        if release.get("draft") or release.get("prerelease"):
            continue

        tag = str(release.get("tag_name") or "")
        published_at = str(release.get("published_at") or "")

        for asset in release.get("assets") or []:
            asset_name = str(asset.get("name") or "")
            kind = ASSETS.get(asset_name)

            if kind is None:
                continue

            row = {
                "snapshot_date": snapshot_date,
                "snapshot_time_utc": snapshot_time,
                "tag": tag,
                "published_at": published_at,
                "kind": kind,
                "asset_name": asset_name,
                "asset_id": str(asset.get("id") or ""),
                "download_count": str(asset.get("download_count") or 0),
            }

            # Same-day manual reruns refresh the row instead of duplicating it.
            key = (snapshot_date, tag, asset_name)
            rows[key] = row
            matched_assets += 1

    write_rows(OUTPUT_PATH, rows)

    print(
        f"Recorded {matched_assets} counted release asset(s) for "
        f"{snapshot_date} in {OUTPUT_PATH}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
