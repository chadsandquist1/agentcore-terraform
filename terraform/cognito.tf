data "aws_cognito_user_pool" "shared" {
  user_pool_id = "us-east-1_jCtPXwqXV"
}

resource "aws_cognito_user_pool_client" "receipt_classifier" {
  name         = "${var.prefix}-client"
  user_pool_id = data.aws_cognito_user_pool.shared.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  generate_secret                      = false
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation              = true
  access_token_validity                = 60
  id_token_validity                    = 60
  refresh_token_validity               = 30
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}
