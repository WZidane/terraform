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