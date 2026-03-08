provider "aws" {
  region = var.aws_region
}

resource "aws_dynamodb_table" "polls" {
  name           = "Polls"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = { Project = "Voteka" }
}

resource "aws_dynamodb_table" "votes" {
  name           = "Votes"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "user_id" # cognito sub
    type = "S"
  }

  global_secondary_index {
    name               = "UserIndex"
    hash_key           = "user_id"
    projection_type    = "ALL"
  }

  tags = { Project = "Voteka" }
}

resource "aws_dynamodb_table" "application" {
  name           = "Application"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "user_id" # cognito sub
    type = "S"
  }

  global_secondary_index {
    name               = "UserAppIndex"
    hash_key           = "user_id"
    projection_type    = "ALL"
  }

  tags = { Project = "Voteka" }
}

resource "aws_dynamodb_table" "documents" {
  name           = "Documents"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = { Project = "Voteka" }
}

resource "random_id" "bucket_suffix" {
  byte_length = var.bucket_suffix_byte_length
}

resource "aws_s3_bucket" "documents" {
  bucket = "voteka-documents-${random_id.bucket_suffix.hex}"

  tags = {
    Environment = "Dev"
    Project     = "Voteka"
  }
}

# Bucket S3 pour le frontend
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "voteka-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "FrontendBucket"
    Environment = "Dev"
    Project     = "Voteka"
  }
}

resource "aws_s3_bucket_public_access_block" "web_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# politique d'accès public pour le bucket frontend (lecture seule)
# resource "aws_s3_bucket_policy" "public_read_policy" {
#   depends_on = [aws_s3_bucket_public_access_block.web_access]
  
#   bucket = aws_s3_bucket.frontend_bucket.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid       = "PublicReadGetObject"
#         Effect    = "Allow"
#         Principal = "*"
#         Action    = "s3:GetObject"
#         Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
#       }
#     ]
#   })
# }

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "s3_oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Policy S3 pour que Cloudfront y accède
resource "aws_s3_bucket_policy" "public_read_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.frontend_bucket.arn}/*"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudfront_function" "rewrite_uri" {
  name    = "rewrite-uri"
  runtime = "cloudfront-js-1.0"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // Si l'URL ne finit pas par une extension (ex: .js, .css, .png)
    // et qu'elle n'est pas la racine (/), on ajoute .html
    if (!uri.includes('.') && uri !== '/') {
        request.uri += '.html';
    }
    return request;
}
EOF
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamo_access" {
  name = "lambda_dynamo_access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Scan",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
        ]

        Resource = [
          aws_dynamodb_table.votes.arn,
          aws_dynamodb_table.polls.arn,
          aws_dynamodb_table.application.arn, 
          aws_dynamodb_table.documents.arn    
        ]
      }
    ]
  })
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "lambda_function_src.zip"
}

resource "aws_lambda_function" "polls_lambda" {
  function_name = "voteka_polls_handler"
  filename      = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  role    = aws_iam_role.lambda_role.arn
  runtime = "python3.11"
  handler = "lambda_polls.lambda_handler"

  environment {
    variables = {
      POLLS_TABLE = aws_dynamodb_table.polls.name
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.voteka_pool.id
      COGNITO_REGION = var.cognito_region
    }
  }
}

resource "aws_lambda_function" "votes_lambda" {
  function_name = "voteka_votes_handler"
  filename      = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  role    = aws_iam_role.lambda_role.arn
  runtime = "python3.11"
  handler = "lambda_votes.lambda_handler"

  environment {
    variables = {
      VOTES_TABLE = aws_dynamodb_table.votes.name
      POLLS_TABLE = aws_dynamodb_table.polls.name
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.voteka_pool.id
      COGNITO_REGION = var.cognito_region
    }
  }
}

resource "aws_apigatewayv2_api" "voteka_api" {
  name          = "voteka-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    # Pour le dev, tout est ouvert
    allow_origins = ["*"] 

    allow_methods = ["GET", "POST", "OPTIONS", "DELETE", "PUT"]
    
    allow_headers = [
      "content-type", 
      "authorization", 
      "x-amz-date", 
      "x-api-key", 
      "x-amz-security-token"
    ]
    
    max_age = 300
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.voteka_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "polls_int" {
  api_id           = aws_apigatewayv2_api.voteka_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.polls_lambda.invoke_arn
}

resource "aws_apigatewayv2_integration" "votes_int" {
  api_id           = aws_apigatewayv2_api.voteka_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.votes_lambda.invoke_arn
}

# route
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id          = aws_apigatewayv2_api.voteka_api.id
  name            = "cognito-authorizer"
  authorizer_type = "JWT"
  identity_sources = [
    "$request.header.Authorization"
  ]

  jwt_configuration {
    issuer  = "https://cognito-idp.${var.cognito_region}.amazonaws.com/${aws_cognito_user_pool.voteka_pool.id}"
    audience = [aws_cognito_user_pool_client.voteka_client.id]
  }
}

resource "aws_apigatewayv2_route" "get_polls" {
  api_id       = aws_apigatewayv2_api.voteka_api.id
  route_key    = "GET /polls"
  authorization_type = "JWT"
  target       = "integrations/${aws_apigatewayv2_integration.polls_int.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "get_poll_by_id" {
  api_id    = aws_apigatewayv2_api.voteka_api.id
  route_key = "GET /polls/{id}"
  authorization_type = "JWT"
  target    = "integrations/${aws_apigatewayv2_integration.polls_int.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "post_polls" {
  api_id       = aws_apigatewayv2_api.voteka_api.id
  route_key    = "POST /polls"
  target       = "integrations/${aws_apigatewayv2_integration.polls_int.id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "put_polls" {
  api_id       = aws_apigatewayv2_api.voteka_api.id
  route_key    = "PUT /polls/{id}"
  target       = "integrations/${aws_apigatewayv2_integration.polls_int.id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "get_votes" {
  api_id       = aws_apigatewayv2_api.voteka_api.id
  route_key    = "GET /votes"
  target       = "integrations/${aws_apigatewayv2_integration.votes_int.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "post_votes" {
  api_id       = aws_apigatewayv2_api.voteka_api.id
  route_key    = "POST /votes"
  target       = "integrations/${aws_apigatewayv2_integration.votes_int.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
}

# PERMISSIONS 

resource "aws_lambda_permission" "api_gw_polls" {
  statement_id  = "AllowExecutionFromAPIGatewayPolls"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.polls_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.voteka_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_votes" {
  statement_id  = "AllowExecutionFromAPIGatewayVotes"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.votes_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.voteka_api.execution_arn}/*/*"
}

# cognito config
resource "aws_cognito_user_pool" "voteka_pool" {
  name = "voteka-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Configuration de la vérification par email
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Votre code de vérification pour Voteka"
    email_message        = "Votre code est {####}. Bienvenue !"
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true
  }

  schema {
    name                = "given_name"
    attribute_data_type = "String"
    mutable             = true
    required            = true
  }

  schema {
    name                = "family_name"
    attribute_data_type = "String"
    mutable             = true
    required            = true
  }
}

resource "aws_cognito_user_pool_client" "voteka_client" {
  name         = "voteka-client"
  user_pool_id = aws_cognito_user_pool.voteka_pool.id

  generate_secret = false

  # Flux d'authentification autorisés
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

resource "aws_s3_object" "register_page" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "register.html"
  
  content = templatefile("${path.module}/templates/register.html.tpl", {
    user_pool_id = aws_cognito_user_pool.voteka_pool.id,
    client_id    = aws_cognito_user_pool_client.voteka_client.id
  })
  
  content_type = "text/html"
}

resource "aws_s3_object" "poll_page" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "poll.html"
  
  content = templatefile("${path.module}/templates/poll.html.tpl", {
    user_pool_id = aws_cognito_user_pool.voteka_pool.id,
    client_id    = aws_cognito_user_pool_client.voteka_client.id
    api_url      = aws_apigatewayv2_api.voteka_api.api_endpoint
  })
  
  content_type = "text/html"
}

resource "aws_s3_object" "login_page" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "login.html"
  content      = templatefile("${path.module}/templates/login.html.tpl", {
    user_pool_id = aws_cognito_user_pool.voteka_pool.id,
    client_id    = aws_cognito_user_pool_client.voteka_client.id
  })
  content_type = "text/html"
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"

  content = templatefile("${path.module}/templates/index.html.tpl", {
    user_pool_id = aws_cognito_user_pool.voteka_pool.id,
    client_id    = aws_cognito_user_pool_client.voteka_client.id,
    api_url = aws_apigatewayv2_api.voteka_api.api_endpoint
  })
  
  content_type = "text/html"
}

resource "aws_s3_object" "create-poll_page" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "create-poll.html"
  content      = templatefile("${path.module}/templates/create-poll.html.tpl", {
    user_pool_id = aws_cognito_user_pool.voteka_pool.id,
    client_id    = aws_cognito_user_pool_client.voteka_client.id,
    api_url = aws_apigatewayv2_api.voteka_api.api_endpoint
  })
  content_type = "text/html"
}

resource "aws_s3_object" "header_js" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "header.js"
  
  source       = "${path.module}/templates/header.js" 
  
  content_type = "application/javascript"

}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = "S3Origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    # C'est ici qu'on lie la fonction pour avoir les URLs sans .html
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_uri.arn
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Fonction d'invalidation automatique du cache CloudFront si maj d'un fichier html pour test
resource "null_resource" "invalidate_cache" {
  # NE PAS OUBLIER DE RAJOUTER LES NOUVEAUX FICHIERS HTML/JS
  triggers = {
    index_hash    = aws_s3_object.index.etag
    login_hash    = aws_s3_object.login_page.etag
    register_hash = aws_s3_object.register_page.etag
    poll_hash = aws_s3_object.poll_page.etag
    header_hash   = aws_s3_object.header_js.etag
    create_poll_hash = aws_s3_object.create-poll_page.etag
  }

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.s3_distribution.id} --paths '/*'"
  }
}