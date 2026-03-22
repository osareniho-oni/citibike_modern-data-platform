#!/usr/bin/env python3
"""
Data Quality Validation Script
Checks for duplicate keys and validates record counts across all dbt models
"""

import os
from google.cloud import bigquery
from tabulate import tabulate
import sys

# Initialize BigQuery client
client = bigquery.Client()

# Get project and dataset from environment or use defaults
PROJECT_ID = os.getenv('GCP_PROJECT_ID', 'nyc-citibike-data-platform')
DATASET_PREFIX = os.getenv('DBT_DATASET', 'dbt_gabby')

print(f"🔍 Validating data quality for project: {PROJECT_ID}")
print(f"📊 Dataset prefix: {DATASET_PREFIX}")
print("=" * 80)

# ============================================================================
# 1. CHECK FOR DUPLICATE KEYS
# ============================================================================

print("\n" + "=" * 80)
print("1. CHECKING FOR DUPLICATE KEYS")
print("=" * 80)

duplicate_checks = []

# Staging models
queries = {
    'stg_trips': {
        'table': f'{PROJECT_ID}.staging.stg_trips',
        'key': 'ride_id',
        'composite': False
    },
    'stg_weather': {
        'table': f'{PROJECT_ID}.staging.stg_weather',
        'key': 'weather_date',
        'composite': False
    },
    'stg_station_status': {
        'table': f'{PROJECT_ID}.staging.stg_station_status',
        'key': ['station_id', 'last_reported'],
        'composite': True
    },
    # Intermediate models
    'int_station_metrics': {
        'table': f'{PROJECT_ID}.staging.int_station_metrics',
        'key': ['station_id', 'reported_at_5min'],
        'composite': True
    },
    'int_station_daily_metrics': {
        'table': f'{PROJECT_ID}.staging.int_station_daily_metrics',
        'key': ['station_id', 'date_day'],
        'composite': True
    },
    'int_trip_station_daily': {
        'table': f'{PROJECT_ID}.staging.int_trip_station_daily',
        'key': ['station_id', 'date_day'],
        'composite': True
    },
    'int_station_weather_daily': {
        'table': f'{PROJECT_ID}.staging.int_station_weather_daily',
        'key': ['station_id', 'date_day'],
        'composite': True
    },
    'int_station_daily_fact': {
        'table': f'{PROJECT_ID}.staging.int_station_daily_fact',
        'key': ['station_id', 'date_day'],
        'composite': True
    },
    # Dimension tables
    'dim_date': {
        'table': f'{PROJECT_ID}.marts.dim_date',
        'key': 'date_key',
        'composite': False
    },
    'dim_station': {
        'table': f'{PROJECT_ID}.marts.dim_station',
        'key': 'station_key',
        'composite': False
    },
    'dim_time': {
        'table': f'{PROJECT_ID}.marts.dim_time',
        'key': 'time_key',
        'composite': False
    },
    'dim_user_type': {
        'table': f'{PROJECT_ID}.marts.dim_user_type',
        'key': 'user_type_key',
        'composite': False
    },
    # Fact tables
    'fct_trips': {
        'table': f'{PROJECT_ID}.marts.fct_trips',
        'key': 'trip_key',
        'composite': False
    },
    'fct_station_day': {
        'table': f'{PROJECT_ID}.marts.fct_station_day',
        'key': ['station_key', 'date_key'],
        'composite': True
    }
}

for model_name, config in queries.items():
    try:
        if config['composite']:
            # Composite key check
            key_cols = config['key']
            concat_expr = ' || "|" || '.join([f'CAST({col} AS STRING)' for col in key_cols])
            query = f"""
                SELECT 
                    COUNT(*) as total_records,
                    COUNT(DISTINCT {concat_expr}) as unique_keys
                FROM `{config['table']}`
            """
        else:
            # Single key check
            query = f"""
                SELECT 
                    COUNT(*) as total_records,
                    COUNT(DISTINCT {config['key']}) as unique_keys
                FROM `{config['table']}`
            """
        
        result = client.query(query).result()
        row = list(result)[0]
        total = row.total_records
        unique = row.unique_keys
        duplicates = total - unique
        
        status = '✅ PASS' if duplicates == 0 else '❌ FAIL'
        key_display = ' + '.join(config['key']) if config['composite'] else config['key']
        
        duplicate_checks.append({
            'Model': model_name,
            'Key': key_display,
            'Total Records': f'{total:,}',
            'Unique Keys': f'{unique:,}',
            'Duplicates': duplicates,
            'Status': status
        })
        
    except Exception as e:
        duplicate_checks.append({
            'Model': model_name,
            'Key': 'N/A',
            'Total Records': 'ERROR',
            'Unique Keys': 'ERROR',
            'Duplicates': 'ERROR',
            'Status': f'⚠️ {str(e)[:30]}'
        })

print("\n" + tabulate(duplicate_checks, headers='keys', tablefmt='grid'))

# ============================================================================
# 2. RECORD COUNT CONSISTENCY
# ============================================================================

print("\n" + "=" * 80)
print("2. RECORD COUNT CONSISTENCY")
print("=" * 80)

consistency_checks = []

# Trip counts across layers
try:
    query = f"""
        SELECT
            'stg_trips' as layer,
            COUNT(*) as record_count
        FROM `{PROJECT_ID}.staging.stg_trips`
        UNION ALL
        SELECT
            'fct_trips' as layer,
            COUNT(*) as record_count
        FROM `{PROJECT_ID}.marts.fct_trips`
    """
    result = client.query(query).result()
    counts = {row.layer: row.record_count for row in result}
    
    status = '✅ PASS' if len(set(counts.values())) == 1 else '⚠️ WARNING'
    consistency_checks.append({
        'Check': 'Trip Counts',
        'stg_trips': f'{counts.get("stg_trips", 0):,}',
        'fct_trips': f'{counts.get("fct_trips", 0):,}',
        'Status': status
    })
except Exception as e:
    consistency_checks.append({
        'Check': 'Trip Counts',
        'stg_trips': 'ERROR',
        'fct_trips': 'ERROR',
        'Status': f'⚠️ {str(e)[:30]}'
    })

print("\n" + tabulate(consistency_checks, headers='keys', tablefmt='grid'))

# ============================================================================
# 3. FOREIGN KEY INTEGRITY
# ============================================================================

print("\n" + "=" * 80)
print("3. FOREIGN KEY INTEGRITY CHECKS")
print("=" * 80)

fk_checks = []

fk_queries = {
    'fct_trips → dim_station (start)': f"""
        SELECT COUNT(*) as orphaned
        FROM `{PROJECT_ID}.marts.fct_trips` f
        LEFT JOIN `{PROJECT_ID}.marts.dim_station` d
            ON f.start_station_key = d.station_key
        WHERE d.station_key IS NULL
    """,
    'fct_trips → dim_station (end)': f"""
        SELECT COUNT(*) as orphaned
        FROM `{PROJECT_ID}.marts.fct_trips` f
        LEFT JOIN `{PROJECT_ID}.marts.dim_station` d
            ON f.end_station_key = d.station_key
        WHERE d.station_key IS NULL
    """,
    'fct_trips → dim_date (start)': f"""
        SELECT COUNT(*) as orphaned
        FROM `{PROJECT_ID}.marts.fct_trips` f
        LEFT JOIN `{PROJECT_ID}.marts.dim_date` d
            ON f.start_date_key = d.date_key
        WHERE d.date_key IS NULL
    """,
    'fct_trips → dim_user_type': f"""
        SELECT COUNT(*) as orphaned
        FROM `{PROJECT_ID}.marts.fct_trips` f
        LEFT JOIN `{PROJECT_ID}.marts.dim_user_type` d
            ON f.user_type_key = d.user_type_key
        WHERE d.user_type_key IS NULL
    """,
    'fct_station_day → dim_station': f"""
        SELECT COUNT(*) as orphaned
        FROM `{PROJECT_ID}.marts.fct_station_day` f
        LEFT JOIN `{PROJECT_ID}.marts.dim_station` d
            ON f.station_key = d.station_key
        WHERE d.station_key IS NULL
    """,
    'fct_station_day → dim_date': f"""
        SELECT COUNT(*) as orphaned
        FROM `{PROJECT_ID}.marts.fct_station_day` f
        LEFT JOIN `{PROJECT_ID}.marts.dim_date` d
            ON f.date_key = d.date_key
        WHERE d.date_key IS NULL
    """
}

for relationship, query in fk_queries.items():
    try:
        result = client.query(query).result()
        orphaned = list(result)[0].orphaned
        status = '✅ PASS' if orphaned == 0 else '❌ FAIL'
        
        fk_checks.append({
            'Relationship': relationship,
            'Orphaned Records': f'{orphaned:,}',
            'Status': status
        })
    except Exception as e:
        fk_checks.append({
            'Relationship': relationship,
            'Orphaned Records': 'ERROR',
            'Status': f'⚠️ {str(e)[:30]}'
        })

print("\n" + tabulate(fk_checks, headers='keys', tablefmt='grid'))

# ============================================================================
# 4. DIMENSION TABLE VALIDATION
# ============================================================================

print("\n" + "=" * 80)
print("4. DIMENSION TABLE VALIDATION")
print("=" * 80)

dim_checks = []

# dim_date validation
try:
    query = f"""
        SELECT
            COUNT(*) as record_count,
            MIN(full_date) as min_date,
            MAX(full_date) as max_date,
            DATE_DIFF(MAX(full_date), MIN(full_date), DAY) + 1 as expected_count
        FROM `{PROJECT_ID}.marts.dim_date`
    """
    result = client.query(query).result()
    row = list(result)[0]
    
    status = '✅ PASS' if row.record_count == row.expected_count else '⚠️ WARNING'
    dim_checks.append({
        'Dimension': 'dim_date',
        'Records': f'{row.record_count:,}',
        'Expected': f'{row.expected_count:,}',
        'Details': f'{row.min_date} to {row.max_date}',
        'Status': status
    })
except Exception as e:
    dim_checks.append({
        'Dimension': 'dim_date',
        'Records': 'ERROR',
        'Expected': 'N/A',
        'Details': str(e)[:30],
        'Status': '⚠️ ERROR'
    })

# dim_station validation
try:
    query = f"""
        SELECT
            COUNT(*) as record_count,
            COUNT(DISTINCT station_id) as unique_stations,
            SUM(CASE WHEN is_current THEN 1 ELSE 0 END) as current_versions
        FROM `{PROJECT_ID}.marts.dim_station`
    """
    result = client.query(query).result()
    row = list(result)[0]
    
    status = '✅ PASS' if row.record_count >= row.unique_stations else '❌ FAIL'
    dim_checks.append({
        'Dimension': 'dim_station',
        'Records': f'{row.record_count:,}',
        'Expected': f'{row.unique_stations:,}+',
        'Details': f'{row.current_versions:,} current',
        'Status': status
    })
except Exception as e:
    dim_checks.append({
        'Dimension': 'dim_station',
        'Records': 'ERROR',
        'Expected': 'N/A',
        'Details': str(e)[:30],
        'Status': '⚠️ ERROR'
    })

# dim_time validation
try:
    query = f"""
        SELECT COUNT(*) as record_count
        FROM `{PROJECT_ID}.marts.dim_time`
    """
    result = client.query(query).result()
    count = list(result)[0].record_count
    
    status = '✅ PASS' if count == 24 else '❌ FAIL'
    dim_checks.append({
        'Dimension': 'dim_time',
        'Records': f'{count:,}',
        'Expected': '24',
        'Details': '24 hours (0-23)',
        'Status': status
    })
except Exception as e:
    dim_checks.append({
        'Dimension': 'dim_time',
        'Records': 'ERROR',
        'Expected': '24',
        'Details': str(e)[:30],
        'Status': '⚠️ ERROR'
    })

# dim_user_type validation
try:
    query = f"""
        SELECT COUNT(*) as record_count
        FROM `{PROJECT_ID}.marts.dim_user_type`
    """
    result = client.query(query).result()
    count = list(result)[0].record_count
    
    status = '✅ PASS' if count == 3 else '❌ FAIL'
    dim_checks.append({
        'Dimension': 'dim_user_type',
        'Records': f'{count:,}',
        'Expected': '3',
        'Details': 'member, casual, unknown',
        'Status': status
    })
except Exception as e:
    dim_checks.append({
        'Dimension': 'dim_user_type',
        'Records': 'ERROR',
        'Expected': '3',
        'Details': str(e)[:30],
        'Status': '⚠️ ERROR'
    })

print("\n" + tabulate(dim_checks, headers='keys', tablefmt='grid'))

# ============================================================================
# 5. NULL KEY CHECKS
# ============================================================================

print("\n" + "=" * 80)
print("5. NULL KEY CHECKS")
print("=" * 80)

null_checks = []

# fct_trips NULL keys
try:
    query = f"""
        SELECT
            SUM(CASE WHEN trip_key IS NULL THEN 1 ELSE 0 END) as null_trip_key,
            SUM(CASE WHEN start_station_key IS NULL THEN 1 ELSE 0 END) as null_start_station,
            SUM(CASE WHEN end_station_key IS NULL THEN 1 ELSE 0 END) as null_end_station,
            SUM(CASE WHEN start_date_key IS NULL THEN 1 ELSE 0 END) as null_start_date,
            SUM(CASE WHEN user_type_key IS NULL THEN 1 ELSE 0 END) as null_user_type
        FROM `{PROJECT_ID}.marts.fct_trips`
    """
    result = client.query(query).result()
    row = list(result)[0]
    
    total_nulls = (row.null_trip_key + row.null_start_station + row.null_end_station + 
                   row.null_start_date + row.null_user_type)
    status = '✅ PASS' if total_nulls == 0 else '❌ FAIL'
    
    null_checks.append({
        'Table': 'fct_trips',
        'NULL trip_key': row.null_trip_key,
        'NULL start_station': row.null_start_station,
        'NULL end_station': row.null_end_station,
        'NULL date': row.null_start_date,
        'NULL user_type': row.null_user_type,
        'Status': status
    })
except Exception as e:
    null_checks.append({
        'Table': 'fct_trips',
        'NULL trip_key': 'ERROR',
        'NULL start_station': 'ERROR',
        'NULL end_station': 'ERROR',
        'NULL date': 'ERROR',
        'NULL user_type': 'ERROR',
        'Status': f'⚠️ {str(e)[:20]}'
    })

# fct_station_day NULL keys
try:
    query = f"""
        SELECT
            SUM(CASE WHEN station_key IS NULL THEN 1 ELSE 0 END) as null_station_key,
            SUM(CASE WHEN date_key IS NULL THEN 1 ELSE 0 END) as null_date_key
        FROM `{PROJECT_ID}.marts.fct_station_day`
    """
    result = client.query(query).result()
    row = list(result)[0]
    
    total_nulls = row.null_station_key + row.null_date_key
    status = '✅ PASS' if total_nulls == 0 else '❌ FAIL'
    
    null_checks.append({
        'Table': 'fct_station_day',
        'NULL trip_key': 'N/A',
        'NULL start_station': row.null_station_key,
        'NULL end_station': 'N/A',
        'NULL date': row.null_date_key,
        'NULL user_type': 'N/A',
        'Status': status
    })
except Exception as e:
    null_checks.append({
        'Table': 'fct_station_day',
        'NULL trip_key': 'N/A',
        'NULL start_station': 'ERROR',
        'NULL end_station': 'N/A',
        'NULL date': 'ERROR',
        'NULL user_type': 'N/A',
        'Status': f'⚠️ {str(e)[:20]}'
    })

print("\n" + tabulate(null_checks, headers='keys', tablefmt='grid'))

# ============================================================================
# SUMMARY
# ============================================================================

print("\n" + "=" * 80)
print("VALIDATION SUMMARY")
print("=" * 80)

total_checks = len(duplicate_checks) + len(fk_checks) + len(dim_checks) + len(null_checks)
passed = sum(1 for c in duplicate_checks if '✅' in c['Status'])
passed += sum(1 for c in fk_checks if '✅' in c['Status'])
passed += sum(1 for c in dim_checks if '✅' in c['Status'])
passed += sum(1 for c in null_checks if '✅' in c['Status'])

failed = sum(1 for c in duplicate_checks if '❌' in c['Status'])
failed += sum(1 for c in fk_checks if '❌' in c['Status'])
failed += sum(1 for c in dim_checks if '❌' in c['Status'])
failed += sum(1 for c in null_checks if '❌' in c['Status'])

warnings = total_checks - passed - failed

print(f"\n✅ PASSED: {passed}/{total_checks}")
print(f"❌ FAILED: {failed}/{total_checks}")
print(f"⚠️  WARNINGS: {warnings}/{total_checks}")

if failed > 0:
    print("\n❌ VALIDATION FAILED - Please review the failures above")
    sys.exit(1)
else:
    print("\n✅ ALL VALIDATIONS PASSED")
    sys.exit(0)