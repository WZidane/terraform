provider "aws" {
  region = "eu-north-1"
}

resource "aws_dynamodb_table" "candidats" {
  name           = "Candidats"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Environment = "Dev"
    Project     = "Voteka"
  }
}

resource "aws_dynamodb_table" "votes" {
  name           = "Votes"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Environment = "Dev"
    Project     = "Voteka"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
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
  bucket = "frontend-bucket-${random_id.bucket_suffix.hex}"

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
resource "aws_s3_bucket_policy" "public_read_policy" {
  depends_on = [aws_s3_bucket_public_access_block.web_access]
  
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "web_config" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  
  # On lit le fichier brut et on remplace le texte
  content = replace(
    file("${path.module}/index.html.tpl"), 
    "{api_url}", 
    "${aws_apigatewayv2_api.voteka_api.api_endpoint}/candidats"
  )
  
  content_type = "text/html"
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
          "dynamodb:Query"
        ]

        Resource = [
          aws_dynamodb_table.candidats.arn,
          aws_dynamodb_table.votes.arn
        ]
      }
    ]
  })
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file  = "${path.module}/src/lambda.py"
  output_path = "lambda_function_src.zip"
}

resource "aws_lambda_function" "voteka_lambda" {
  function_name = "voteka_handler"
  filename      = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  role    = aws_iam_role.lambda_role.arn
  runtime = "python3.11"
  handler = "lambda.lambda_handler"

  environment {
    variables = {
      CANDIDATS_TABLE = aws_dynamodb_table.candidats.name
    }
  }
}

resource "aws_apigatewayv2_api" "voteka_api" {
  name          = "voteka-api"
  protocol_type = "HTTP"
  
  # Config CORS
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.voteka_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_int" {
  api_id           = aws_apigatewayv2_api.voteka_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.voteka_lambda.invoke_arn
}

# route
resource "aws_apigatewayv2_route" "get_candidats" {
  api_id    = aws_apigatewayv2_api.voteka_api.id
  route_key = "GET /candidats"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_int.id}"
}

# permission
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.voteka_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.voteka_api.execution_arn}/*/*"
}

output "url_api" {
  description = "URL de ton API à appeler en JS :"
  value       = "${aws_apigatewayv2_api.voteka_api.api_endpoint}/candidats"
}

output "url_du_site" {
  description = "Lien pour accéder au site :"
  value       = "http://${aws_s3_bucket_website_configuration.web_config.website_endpoint}"
}