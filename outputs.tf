output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.voteka_pool.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.voteka_client.id
}

output "url_api" {
  description = "URL de l'API à appeler en JS :"
  value       = "${aws_apigatewayv2_api.voteka_api.api_endpoint}"
}

output "url_du_site" {
  description = "Lien pour accéder au site :"
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}