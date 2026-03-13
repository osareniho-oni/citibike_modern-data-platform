# Looker Setup Guide

This guide walks you through setting up Looker (Google Cloud core) for your CitiBike analytics platform using Terraform.

## Prerequisites

1. **GCP Project with Looker API enabled**
   ```bash
   gcloud services enable looker.googleapis.com --project=nyc-citibike-data-platform
   ```

2. **OAuth 2.0 Credentials**
   - Required for Looker authentication
   - Must be created before running Terraform
   - Go to: https://console.cloud.google.com/apis/credentials?project=nyc-citibike-data-platform
C

## Step 1: Create OAuth 2.0 Credentials

### Via GCP Console

1. Navigate to: https://console.cloud.google.com/apis/credentials?project=nyc-citibike-data-platform

2. Click **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**

3. Configure the OAuth consent screen (if not already done):
   - User Type: **Internal** (for organization use) or **External**
   - App name: `CitiBike Looker Analytics`
   - User support email: Your email
   - Developer contact: Your email
   - Scopes: Add `openid`, `email`, `profile`

4. Create OAuth Client ID:
   - Application type: **Web application**
   - Name: `citibike-looker-oauth`
   - Authorized redirect URIs: 
     - `https://looker.googleapis.com/auth/callback`
     - You'll add the Looker instance URL after creation

5. **Save the Client ID and Client Secret** - you'll need these for Terraform

### Via gcloud CLI

```bash
# Create OAuth client (requires manual consent screen setup first)
gcloud alpha iap oauth-clients create \
  --display-name="CitiBike Looker OAuth" \
  --project=nyc-citibike-data-platform
```

## Step 2: Configure Terraform Variables

### Option A: Update terraform.tfvars

```hcl
# Add to terraform-gcp/terraform.tfvars
looker_instance_name       = "citibike-looker"
looker_platform_edition    = "LOOKER_CORE_STANDARD"
looker_region              = "us-central1"
looker_oauth_client_id     = "YOUR_CLIENT_ID_HERE"
looker_oauth_client_secret = "YOUR_CLIENT_SECRET_HERE"
looker_custom_domain       = null  # Optional
```

### Option B: Use Environment Variables (Recommended for CI/CD)

```bash
export TF_VAR_looker_oauth_client_id="YOUR_CLIENT_ID"
export TF_VAR_looker_oauth_client_secret="YOUR_CLIENT_SECRET"
```

## Step 3: Deploy Looker with Terraform

```bash
cd terraform-gcp

# Initialize Terraform (if not already done)
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
```

**Expected Output:**
```
module.looker.google_looker_instance.citibike_looker: Creating...
module.looker.google_bigquery_connection.looker_connection: Creating...
module.looker.google_looker_instance.citibike_looker: Creation complete after 15m
module.looker.google_project_iam_member.looker_bigquery_access: Creating...

Outputs:
looker_instance_url = "https://YOUR_INSTANCE.looker.app"
looker_instance_id = "projects/nyc-citibike-data-platform/locations/us-central1/instances/citibike-looker"
looker_service_account = "looker-sa@nyc-citibike-data-platform.iam.gserviceaccount.com"
```

**Note:** Looker instance creation takes **10-15 minutes**.

## Step 4: Update OAuth Redirect URIs

After Looker instance is created:

1. Get the Looker instance URL:
   ```bash
   terraform output looker_instance_url
   ```

2. Go back to GCP Console → APIs & Services → Credentials

3. Edit your OAuth client and add:
   - `https://YOUR_INSTANCE.looker.app/auth/callback`
   - `https://YOUR_INSTANCE.looker.app/login/oauth_callback`

## Step 5: Configure BigQuery Connection in Looker

1. Access your Looker instance at the URL from `terraform output looker_instance_url`

2. Navigate to **Admin** → **Connections** → **Add Connection**

3. Configure BigQuery connection:
   - **Name:** `citibike_bigquery`
   - **Dialect:** BigQuery Standard SQL
   - **Project ID:** `nyc-citibike-data-platform`
   - **Dataset:** `marts` (or leave blank to access all datasets)
   - **Authentication:** Service Account
   - **Service Account Email:** Use the output from `terraform output looker_service_account`

4. Test the connection

## Step 6: Create LookML Project

1. In Looker, go to **Develop** → **Manage LookML Projects**

2. Create new project:
   - **Project Name:** `citibike_analytics`
   - **Connection:** `citibike_bigquery`
   - **Git Repository:** (Optional) Link to your repo

3. Create model file (`citibike_analytics.model.lkml`):
   ```lookml
   connection: "citibike_bigquery"
   
   include: "/views/**/*.view.lkml"
   include: "/dashboards/**/*.dashboard.lookml"
   
   explore: fct_trips {
     label: "Trip Analysis"
     
     join: dim_station {
       sql_on: ${fct_trips.start_station_key} = ${dim_station.station_key} ;;
       relationship: many_to_one
     }
     
     join: dim_date {
       sql_on: ${fct_trips.date_key} = ${dim_date.date_key} ;;
       relationship: many_to_one
     }
     
     join: dim_user_type {
       sql_on: ${fct_trips.user_type_key} = ${dim_user_type.user_type_key} ;;
       relationship: many_to_one
     }
   }
   
   explore: fct_station_day {
     label: "Station Operations"
     
     join: dim_station {
       sql_on: ${fct_station_day.station_key} = ${dim_station.station_key} ;;
       relationship: many_to_one
     }
     
     join: dim_date {
       sql_on: ${fct_station_day.date_key} = ${dim_date.date_key} ;;
       relationship: many_to_one
     }
   }
   ```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Terraform Module: looker                                │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  google_looker_instance                          │    │
│  │  • Name: citibike-looker                         │    │
│  │  • Edition: LOOKER_CORE_STANDARD                 │    │
│  │  • Region: us-central1                           │    │
│  │  • OAuth: Configured                             │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  google_bigquery_connection                      │    │
│  │  • Connection ID: looker-bigquery-connection     │    │
│  │  • Type: Cloud Resource                          │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  IAM Permissions                                 │    │
│  │  • Role: roles/bigquery.dataViewer               │    │
│  │  • Member: Looker Service Account                │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  BigQuery Datasets                                       │
│  • raw (station_status_streaming, trips, weather)       │
│  • staging (stg_trips, stg_weather, stg_station_status) │
│  • marts (dim_*, fct_*)                                  │
└─────────────────────────────────────────────────────────┘
```

## Cost Considerations

### Looker Pricing (as of 2026)

- **LOOKER_CORE_STANDARD:** ~$5,000/month (5 users included)
- **LOOKER_CORE_ENTERPRISE:** ~$10,000/month (10 users included)
- **Additional Users:** ~$50-100/user/month

### Cost Optimization Tips

1. **Start with LOOKER_CORE_STANDARD** for development
2. **Use scheduled queries** instead of live queries where possible
3. **Implement aggregate tables** for frequently accessed metrics
4. **Set up query caching** to reduce BigQuery costs
5. **Monitor usage** via Looker System Activity

## Troubleshooting

### Issue: OAuth Error "redirect_uri_mismatch"

**Solution:** Ensure the Looker instance URL is added to OAuth authorized redirect URIs

### Issue: "Permission denied" when querying BigQuery

**Solution:** Verify IAM permissions:
```bash
gcloud projects get-iam-policy nyc-citibike-data-platform \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:looker-sa@*"
```

### Issue: Looker instance creation timeout

**Solution:** Looker instances take 10-15 minutes to provision. If it exceeds 20 minutes:
```bash
# Check instance status
gcloud looker instances describe citibike-looker \
  --location=us-central1 \
  --project=nyc-citibike-data-platform
```

### Issue: Cannot connect to BigQuery from Looker

**Solution:** 
1. Verify the service account has `roles/bigquery.dataViewer`
2. Check that the BigQuery connection uses the correct project ID
3. Test connection in Looker Admin → Connections

## Security Best Practices

1. **Use Internal OAuth** for organization-only access
2. **Enable MFA** for all Looker users
3. **Implement row-level security** in LookML for sensitive data
4. **Audit access logs** regularly
5. **Use service account** with minimal required permissions
6. **Store OAuth secrets** in Secret Manager (not in terraform.tfvars)

### Using Secret Manager (Recommended)

```bash
# Store OAuth credentials in Secret Manager
echo -n "YOUR_CLIENT_ID" | gcloud secrets create looker-oauth-client-id \
  --data-file=- \
  --project=nyc-citibike-data-platform

echo -n "YOUR_CLIENT_SECRET" | gcloud secrets create looker-oauth-client-secret \
  --data-file=- \
  --project=nyc-citibike-data-platform

# Update Terraform to use Secret Manager
# (requires google_secret_manager_secret_version data source)
```

## Next Steps

1. ✅ Deploy Looker instance with Terraform
2. ✅ Configure BigQuery connection
3. ✅ Create LookML project
4. 📊 Build views for dimension and fact tables
5. 📊 Create explores for trip and station analysis
6. 📊 Design dashboards for operational metrics
7. 📊 Set up scheduled reports and alerts

## Resources

- [Looker Documentation](https://cloud.google.com/looker/docs)
- [LookML Reference](https://cloud.google.com/looker/docs/lookml-reference)
- [BigQuery Connection Guide](https://cloud.google.com/looker/docs/db-config-google-bigquery)
- [Terraform Looker Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/looker_instance)

---

**Questions?** Check the [main README](../README.md) or open an issue.