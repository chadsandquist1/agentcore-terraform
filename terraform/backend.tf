terraform {
  backend "s3" {
    bucket         = "mojodojo-receipt-classifier-tfstate"
    key            = "receipt-classifier/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "mojodojo-receipt-classifier-tfstate-lock"
    encrypt        = true
  }
}
