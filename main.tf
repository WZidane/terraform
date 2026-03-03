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

  # Hébergement statique activé
  # website {
  #   index_document = "index.html"
  #   error_document = "index.html"
  # }

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

resource "aws_s3_object" "index_test" {
  bucket = aws_s3_bucket.frontend_bucket.id
  key = "index.html"
  
  source = "${path.module}/index.html"

  etag = filemd5("${path.module}/index.html")
  
  content_type = "text/html"
}

output "url_du_site" {
  description = "Lien pour accéder au site :"
  value       = "http://${aws_s3_bucket_website_configuration.web_config.website_endpoint}"
}