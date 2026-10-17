"""Prepare a next-day readiness research table from the official PMData archive.

Run against an extracted pmdata.zip. Do not commit the resulting table: it
contains participant-level health observations.
"""
import argparse
import csv
import json
from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('data_root', type=Path, help='Directory containing p01 ... p16 from pmdata.zip')
parser.add_argument('output_dir', type=Path, help='Private, ignored output directory')
args = parser.parse_args()
DATA = args.data_root
OUT_DIR = args.output_dir
OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT = OUT_DIR / 'pmdata_next_day_readiness.csv'
FEATURES = ('resting_heart_rate', 'hrv_sdnn', 'respiratory_rate', 'sleep_duration_min',
            'steps', 'active_energy_kcal', 'exercise_duration_min')


def numeric(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


rows = []
stats = []
for folder in sorted(DATA.glob('p*')):
    wellness = {}
    with (folder / 'pmsys/wellness.csv').open(encoding='utf-8-sig', newline='') as stream:
        for record in csv.DictReader(stream):
            day = record['effective_time_frame'][:10]
            if numeric(record['readiness']) is not None:
                wellness[day] = numeric(record['readiness'])

    rhr = {}
    rhr_file = folder / 'fitbit/resting_heart_rate.json'
    if rhr_file.exists():
        for record in json.loads(rhr_file.read_text(encoding='utf-8')):
            value = record.get('value', {})
            hr = numeric(value.get('value'))
            if hr is not None:
                rhr[record['dateTime'][:10]] = hr

    steps = defaultdict(float)
    for record in json.loads((folder / 'fitbit/steps.json').read_text(encoding='utf-8')):
        value = numeric(record.get('value'))
        if value is not None:
            steps[record['dateTime'][:10]] += value

    sleep = {}
    for record in json.loads((folder / 'fitbit/sleep.json').read_text(encoding='utf-8')):
        if not record.get('mainSleep'):
            continue
        minutes = numeric(record.get('minutesAsleep'))
        if minutes is not None:
            sleep[record['dateOfSleep'][:10]] = minutes

    count = 0
    for day, prior_readiness in wellness.items():
        next_day = (date.fromisoformat(day) + timedelta(days=1)).isoformat()
        if next_day not in wellness:
            continue
        if day not in steps or day not in sleep:
            continue
        row = {'user_id': folder.name, 'date': day, 'next_day_recovery': wellness[next_day],
               'prior_readiness': prior_readiness,
               'resting_heart_rate': rhr.get(day, ''), 'sleep_duration_min': sleep[day],
               'steps': steps[day]}
        for feature in FEATURES:
            row.setdefault(feature, '')
        rows.append(row)
        count += 1
    stats.append((folder.name, len(wellness), count))

rows.sort(key=lambda row: (row['user_id'], row['date']))
with OUT.open('w', newline='', encoding='utf-8') as stream:
    writer = csv.DictWriter(stream, fieldnames=('user_id', 'date', *FEATURES,
                                                 'prior_readiness', 'next_day_recovery'))
    writer.writeheader()
    writer.writerows(rows)
metadata = {
    'dataset_name': 'PMData (Simula), subset from official pmdata.zip',
    'license': 'CC BY 4.0 per current Simula page; 2020 paper says CC BY-NC 4.0; conflict unresolved',
    'source': 'https://datasets.simula.no/pmdata/',
    'consent_basis': 'Participants signed consent for collection and publication per Simula dataset page',
    'label_source': 'user_self_report',
    'label_horizon': 'next calendar day wellness readiness (0-10), prior calendar day features',
}
(OUT_DIR / 'pmdata_metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
print(json.dumps({'rows': len(rows), 'participants': len({r['user_id'] for r in rows}),
                  'date_min': min((r['date'] for r in rows), default=None),
                  'date_max': max((r['date'] for r in rows), default=None),
                  'subject_counts': stats}, indent=2))
