resource "google_service_account" "sa" {
  for_each = toset(var.service_accounts)

  account_id   = each.value
  display_name = each.value
}