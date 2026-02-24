kestraconfs--STEPS:
create project in gcp

enable billing

enable apis:
    gcloud services enable iam.googleapis.com
    gcloud services enable cloudresourcemanager.googleapis.com
    gcloud services enable bigquery.googleapis.com
    gcloud services enable storage.googleapis.com

authenticate, by running:
    gcloud auth application-default login
    gcloud config set project kestra-dbt-platform

THEN RUN:

terraform init --noly once
terraform plan
terraform apply
terraform destroy --- to destroy created resources

COPY SERVICE PRINCIPAL FROM TERMINAL
eg. 

service_accounts = {
  "dbt-sa" = "dbt-sa@kestra-dbt-platform.iam.gserviceaccount.com"
  "kestra-sa" = "kestra-sa@kestra-dbt-platform.iam.gserviceaccount.com"
  "terraform-sa" = "terraform-sa@kestra-dbt-platform.iam.gserviceaccount.com"
}

From the Google Cloud Console
Go to:
IAM & Admin → Service Accounts
You’ll see all three service accounts there.

⭐ Next steps (important)
Now that the service accounts exist, you will need to generate keys for the ones that require external authentication:
✔️ dbt → needs a service account key
✔️ Kestra → needs a service account key
❌ Terraform SA → does NOT need a key (you authenticate with gcloud)
If you want, I can walk you through:
- generating the keys
- storing them securely
- configuring dbt for BigQuery
- configuring Kestra to use the service account
- writing your first ingestion flow
Just tell me what you want to do next.


--KESTRA SERVER (on linux)--
NOTE: Kestra JAR requires JVM version 21+
To run Kestra from Standalone JAR – No Docker Deployment

This project Runs Kestra from Standalone JAR – No Docker Deployment

Here is your "cheat sheet" for setting up Kestra Standalone with PostgreSQL on Linux. Save this in a note or a script for next time.
1. Download & Rename
bash
# Download the latest binary
curl -LO https://api.kestra.io

# Rename and make executable
mv download kestra
chmod +x kestra
Use code with caution.

2. Prepare Directories
bash
mkdir -p ~/kestra/confs
mkdir -p ~/kestra/plugins
mkdir -p ~/kestra/storage
Use code with caution.

3. Database Setup (PostgreSQL)
Login via sudo -u postgres psql and run:
sql
CREATE DATABASE kestra;
CREATE USER kestra WITH ENCRYPTED PASSWORD 'kestra';
GRANT ALL PRIVILEGES ON DATABASE kestra TO kestra;
\c kestra
GRANT ALL ON SCHEMA public TO kestra;
\q
Use code with caution.

PostgreSQL Documentation | Kestra Standalone Guide
4. Create Configuration (~/kestra/confs/application.yaml)
yaml
kestra:
  queue:
    type: postgres
  repository:
    type: postgres
  storage:
    type: local
    local:
      base-path: "/home/gabby/kestra/storage"

datasources:
  postgres:
    url: jdbc:postgresql://localhost:5432/kestra
    driver-class-name: org.postgresql.Driver
    username: kestra
    password: kestra
Use code with caution.

5. Install Plugins (Optional)
bash
./kestra plugins install --all -p ./plugins
Use code with caution.

6. Start the Server
bash
cd kestra
run ./kestra server standalone --config ./confs/application.yaml


--BIGQUERY CONSIDERATIONS--

🧩 Option 1 — Load CSVs directly into BigQuery
✔ Pros
- Simplest pipeline (download → unzip → upload → load)
- No transformation step
- BigQuery autodetect works well
- Schema drift is handled automatically with your schemaUpdateOptions
- Fast enough for monthly loads
✘ Cons
- CSV is row‑oriented, not columnar
- BigQuery must parse text every time you load
- More expensive long‑term (storage + query cost)
- Slower queries, especially on wide tables
- No compression benefits (CSV compresses poorly compared to Parquet)
When CSV is fine
- You’re doing monthly incremental loads
- You’re not querying the raw table heavily
- You want the simplest possible ingestion path
- You’re okay with BigQuery doing the heavy lifting
For many teams, this is perfectly acceptable.

🧩 Option 2 — Convert to Parquet before loading
✔ Pros
- Columnar format → dramatically faster queries
- Much smaller storage footprint (often 5–10× smaller)
- BigQuery loads Parquet faster
- Schema evolution is easier (Parquet supports optional fields)
- Better compression
- Partitioning + clustering becomes more efficient
✘ Cons
- You must unzip → read CSV → convert to Parquet
- Requires a Python transformation step (Pandas or PyArrow)
- Slightly more compute overhead in Kestra
- More moving parts
When Parquet is worth it
- You expect heavy analytical querying
- You want lower BigQuery costs
- You want faster ingestion
- You want better schema evolution handling
- You want column pruning and predicate pushdown benefits
For a dataset like CitiBike (large, long‑term, analytical), Parquet is often the better strategic choice.

🧠 Practical Recommendation for your pipeline
Given your goals:
- Monthly ingestion
- Partitioned BigQuery table
- Schema drift handling
- Long‑term maintainability
- CI/CD‑driven orchestration
- GCS as a raw zone
Here’s the balanced recommendation:

⭐ Recommended Architecture
Raw Zone (GCS): store the original CSVs (unzipped)
→ This preserves the source of truth
→ No transformations lost
→ Useful for audits or reprocessing
Staging Zone (GCS): store Parquet files
→ Convert CSV → Parquet in Kestra
→ Load Parquet into BigQuery
Warehouse Zone (BigQuery): partitioned table
→ Loaded from Parquet
→ Faster, cheaper, more stable
This is the same pattern used by most modern data engineering teams.

🔥 Will converting to Parquet add overhead?
Yes — but only once per month, and the overhead is small.
A typical CitiBike monthly CSV is:
- 50–200 MB zipped
- 300–800 MB uncompressed
- 50–150 MB as Parquet
Converting CSV → Parquet with PyArrow takes:
- 5–15 seconds per file
- <1 CPU core
- Minimal memory
Kestra can easily handle this.
The long‑term savings in BigQuery query cost and performance far outweigh the small transformation overhead.


--KESTRA PYTHON SDK--
Use the Kestra Python SDK programmatically
Install the Python SDK
This guide demonstrates how to use the Kestra Python SDK to create and execute flows programmatically. Before starting, make sure your Kestra instance is running and accessible via the KESTRA_HOST environment variable. You can store credentials in an .env file:

KESTRA_HOST=http://localhost:8080
KESTRA_USERNAME=admin@kestra.io
KESTRA_PASSWORD=Admin1234

Set up your environment
Create a virtual environment and install the Kestra Python SDK. kestrapy is the core package.

uv venv
source .venv/bin/activate
uv pip install kestrapy
uv pip install python-dotenv  # Optional: for loading .env variables automatically

Tip: Using python-dotenv allows you to store credentials securely and load them automatically when your script runs.

Configure the client
Import and initialize the client with your Kestra credentials:

from kestrapy import Configuration, KestraClient

configuration = Configuration(
    host="http://localhost:8080",
    username="root@root.com",
    password="Root!1234"
)

kestra_client = KestraClient(configuration)

--USING KESTRA SECRETS--
Current Setup (Correct Approach):
Your workflows use Kestra Secrets for GCP credentials:

{{ secret('gcp.service_account') }} - Service account JSON key
{{ secret('gcp.project_id') }} - GCP project ID
{{ secret('gcs.bucket') }} - GCS bucket name
{{ secret('bq.dataset') }} - BigQuery dataset
{{ secret('bq.table') }} - BigQuery table
Why This is Better:
Security: Kestra Secrets are encrypted and stored securely in Kestra's backend
Separation of Concerns:
.env file = Kestra API credentials (for registering flows)
Kestra Secrets = GCP credentials (for workflow execution)
Best Practice: Service account JSON keys should never be in version control or plain text files
What You Need to Do:
Configure these secrets in Kestra UI or via API:

Navigate to Kestra UI → Settings → Secrets
Add each secret with the appropriate values
The service account JSON should be stored as a single secret value

--USING GOOGLE APPLICATION CREDENTIALS--
What you need to do:
In Kestra's KV store, you need to store the entire JSON content of your service account key file, not a path.

For example, if your service account JSON file looks like this:

{
  "type": "service_account",
  "project_id": "your-project",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "...",
  ...
}

json


You would:

Copy the entire JSON content (the whole file)
Store it in Kestra KV with key gcp.service_account
The workflow will automatically create a temp file with this content at runtime
You do NOT need to:

Add a path to your .env file
Store the file path anywhere
Have the JSON file accessible to Kestra
The code dynamically creates the credentials file during workflow execution from the JSON stored in KV.

Run project cd kestra


## Performance Optimization

This pipeline achieves **85% storage reduction** by converting CSV files to Parquet format:
- **Input**: 395 MB of CSV data (3 files, ~3.2M rows)
- **Output**: 57.5 MB of Parquet files
- **Compression Ratio**: 6.9:1 (85% reduction)

The Parquet format provides:
- Columnar storage for faster analytical queries
- Built-in Snappy compression (lossless)
- Optimized for BigQuery's query engine
- Reduced storage costs and faster data transfer

**Result**: Lower cloud storage costs and improved query performance in BigQuery.


ACHIEVEMENTS (Resume):
• Designed and deployed end-to-end data pipeline using Kestra, GCS, and BigQuery to process 
  NYC CitiBike data (3.2M+ monthly records); achieved 85% storage optimization through Parquet 
  conversion with Hive-style partitioning for improved query performance

  OR

• Built cloud-native data pipeline with Kestra orchestrating CSV ingestion, Parquet conversion, 
  and BigQuery loading; optimized storage efficiency by 85% (395MB → 57.5MB) while maintaining 
  data integrity across 3.2M+ records


Start the Server
bash
cd kestra
run ./kestra server standalone --config ./confs/application.yaml


Upload flows
cd kestra
uv run python register_yaml_flows.py