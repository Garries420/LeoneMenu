from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def swedish_time(utc):
    try:
        stockholm = utc.astimezone(ZoneInfo('Europe/Stockholm'))
        return stockholm, stockholm.tzname()
    except ZoneInfoNotFoundError:
        # Windows Python may have no IANA data. Use the installed Windows zone.
        command = (
            "$zone = [TimeZoneInfo]::FindSystemTimeZoneById('W. Europe Standard Time'); "
            f"$utc = [DateTimeOffset]::Parse('{utc.isoformat()}'); "
            "$local = [TimeZoneInfo]::ConvertTime($utc, $zone); "
            "$local.ToString('o', [Globalization.CultureInfo]::InvariantCulture)"
        )
        stockholm = datetime.fromisoformat(subprocess.check_output(
            ['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', command], text=True).strip())
        return stockholm, 'CEST' if stockholm.utcoffset().total_seconds() == 7200 else 'CET'


root = Path(__file__).resolve().parents[1] / 'github-ready'
source = root / 'alliance-skins.html'
html = source.read_text(encoding='utf-8')
ids = re.search(r'<pre id="alliance-skins">([0-9,\s]+)</pre>', html)
if ids is None:
    raise SystemExit('The alliance skins block must contain a list of numeric IDs.')
skins = [int(value.strip()) for value in ids[1].split(',') if value.strip()]
if not skins or any(skin > 311 or skin == 74 for skin in skins) or len(skins) != len(set(skins)):
    raise SystemExit('Check the alliance skin list for invalid or duplicate IDs.')

rosters = re.findall(r'<pre id="alliance-gangs">([^<]*)</pre>', html)
if len(rosters) != 1:
    raise SystemExit('Include one alliance-gangs block in the alliance page.')
seen = set()
for row in rosters[0].split('\n'):
    if not row.strip():
        continue
    fields = [value.strip() for value in row.split('|')]
    if (len(fields) != 3 or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 ._'\-]{0,23}", fields[0])
            or not fields[1] or re.search(r'[\x00-\x1f\x7f]', fields[1])
            or not re.fullmatch(r'[0-9A-Fa-f]{6}', fields[2]) or fields[0].lower() in seen):
        raise SystemExit(f'Invalid or duplicate alliance gang row: {row}')
    seen.add(fields[0].lower())

utc = datetime.now(timezone.utc).replace(microsecond=0)
version = int(utc.timestamp())
stockholm, abbreviation = swedish_time(utc)
date = f'{stockholm:%d/%m/%Y %I:%M%p} {abbreviation}'
path = f'skins/alliance-skins-{stockholm:%Y-%m-%d_%H-%M-%S}_{abbreviation}.html'
pattern = r'<meta name="leone-skins-version" content="(\d+)">(?:\s*<meta name="leone-skins-date" content="[^"]+">)?'
previous = re.search(pattern, html)
if previous is None or version <= int(previous[1]):
    raise SystemExit('The new publication timestamp must be newer than the existing one.')
html = re.sub(pattern, f'<meta name="leone-skins-version" content="{version}">\n'
              f'<meta name="leone-skins-date" content="{date}">', html, count=1)
html = re.sub(r'(<h1>Leone alliance skins</h1>)<p>[^<]+</p>',
              rf'\1<p>Alliance Skin Date: {date}</p>', html, count=1)
html = re.sub(r'<small>[^<]+</small>', '<small>Independent alliance skin list for Leone Menu.</small>', html, count=1)
data = html.encode('utf-8')
(root / 'skins').mkdir(exist_ok=True)
(root / path).write_bytes(data)
source.write_bytes(data)
manifest = {'version': version, 'date': date, 'path': path, 'sha256': hashlib.sha256(data).hexdigest()}
(root / 'skins/latest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')
print(f'{len(skins)} skins and {len(seen)} gangs published locally as {path}')
