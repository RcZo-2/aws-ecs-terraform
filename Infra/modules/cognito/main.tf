resource "aws_cognito_user_pool" "pool" {
  name           = "api-user-pool"
  user_pool_tier = "LITE"
}

resource "aws_cognito_user_pool_client" "client" {
  name = "api-user-pool-client"
  user_pool_id = aws_cognito_user_pool.pool.id
  generate_secret = false
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}
