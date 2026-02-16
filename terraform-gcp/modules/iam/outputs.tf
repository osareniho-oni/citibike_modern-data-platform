output "iam_bindings" {
  value = {
    for k, v in google_project_iam_member.bindings :
    k => {
      member = v.member
      role   = v.role
    }
  }
}