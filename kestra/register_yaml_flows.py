import os
import yaml
from pathlib import Path
from dotenv import load_dotenv
from kestrapy import Configuration, KestraClient
from kestrapy.exceptions import ApiException

# Load environment variables from .env file
env_path = Path(__file__).parent / '.env'
load_dotenv(dotenv_path=env_path)

def load_yaml(path: str) -> str:
    with open(path, "r") as f:
        return f.read()

def main():

    configuration = Configuration(
        host=os.getenv("KESTRA_HOST"),
        username=os.getenv("KESTRA_USERNAME"),
        password=os.getenv("KESTRA_PASSWORD")
    )

    kestra_client = KestraClient(configuration)
    
    # Get tenant from environment or use default
    tenant = os.getenv("KESTRA_TENANT", "main")

    yaml_files = [
        "flows/06_gcp_kv.yml",
        "flows/nyc_bikes_gcs_to_bq.yml",
        "flows/nyc_bikes_parent.yml",
        "flows/nyc_daily_weather_to_bigquery.yml",
        "flows/citibike_station_status.yml"
    ]

    for file in yaml_files:
        try:
            yaml_content = load_yaml(file)
            # Parse YAML to get namespace and id
            flow_data = yaml.safe_load(yaml_content)
            namespace = flow_data.get('namespace')
            flow_id = flow_data.get('id')
            
            # Try to create, if it exists, update instead
            try:
                kestra_client.flows.create_flow(tenant=tenant, body=yaml_content)
                print(f"✔ Created YAML flow: {file}")
            except ApiException as create_error:
                if create_error.status == 422 and "already exists" in str(create_error.body):
                    # Flow exists, update it instead
                    kestra_client.flows.update_flow(
                        tenant=tenant,
                        namespace=namespace,
                        id=flow_id,
                        body=yaml_content
                    )
                    print(f"✔ Updated YAML flow: {file}")
                else:
                    raise
        except ApiException as e:
            print(f"\n❌ Validation failed for {file}")
            print("Status:", e.status)
            print("Reason:", e.reason)
            print("Body:", e.body)
            print("-" * 80)

if __name__ == "__main__":
    main()