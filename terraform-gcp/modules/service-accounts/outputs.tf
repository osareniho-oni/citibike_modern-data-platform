output "service_account_emails" {
  value = { for k, v in google_service_account.sa : k => v.email }
}