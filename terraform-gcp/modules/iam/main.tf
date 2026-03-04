locals {
  roles = {
    terraform-sa = [
      "roles/storage.admin",
      "roles/bigquery.admin",
      "roles/iam.serviceAccountAdmin",
      "roles/resourcemanager.projectIamAdmin"
    ]

    kestra-sa = [
      "roles/storage.admin",
      "roles/bigquery.dataEditor",
      "roles/bigquery.jobUser",
      "roles/pubsub.publisher"
    ]

    dbt-sa = [
      "roles/bigquery.dataEditor",
      "roles/bigquery.jobUser",
      "roles/bigquery.readSessionUser"
    ]
  }
}

# Flatten the structure so each SA-role pair becomes one item
locals {
  sa_role_pairs = flatten([
    for sa, email in var.service_accounts : [
      for role in local.roles[sa] : {
        sa_email = email
        role     = role
        key      = "${sa}-${replace(role, "/", "_")}"
      }
    ]
  ])
}

resource "google_project_iam_member" "bindings" {
  for_each = {
    for pair in local.sa_role_pairs : pair.key => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${each.value.sa_email}"
}