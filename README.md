--STEPS:
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
Download Kestra JAR fileform kestra link:
https://kestra.io/docs/installation/standalone-server#configuration

mkdir -p ~/kestra
cd ~/kestra

-- Move and extract the downloaded ZIP file to the kestra directory --
mv ~/Downloads/kestra-VERSION.zip ~/kestra/
cd ~/kestra
-- Unzip the downloaded ZIP file --
unzip kestra-VERSION.zip

-- Make the Kestra file executable
chmod +x kestra-VERSION

-- mkdir pluggins
mkdir -p ~/kestra/plugins

-- Install plugins
wget https://repo1.maven.org/maven2/io/kestra/plugin/plugin-script-python/1.1.3/plugin-script-python-1.1.3.jar -P plugins/
wget https://repo1.maven.org/maven2/io/kestra/plugin/plugin-gcp/1.1.2/plugin-gcp-1.1.2.jar -P plugins/
wget https://repo1.maven.org/maven2/io/kestra/plugin/plugin-compress/1.1.1/plugin-compress-1.1.1.jar -P plugins/
wget https://repo1.maven.org/maven2/io/kestra/plugin/plugin-serdes/1.3.1/plugin-serdes-1.3.1.jar -P plugins/
wget https://repo1.maven.org/maven2/io/kestra/plugin/plugin-script-shell/1.1.3/plugin-script-shell-1.1.3.jar -P plugins/

-- Run the Kestra server
./kestra-VERSION server local

-- Run Kestra in local mode (quick start) From inside ~/kestra:
./kestra-VERSION server local

-- (Optional) Run in standalone mode with config
If you want the “standalone” mode with an external DB (Postgres, etc.), you’ll need a config file, e.g.:
mkdir -p ~/kestra/config
nano ~/kestra/config/application.yml

-- run kestra with config file --
./kestra-VERSION --config.file=~/kestra/config/application.yml

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

Run project uv run python register_yaml_flows.py