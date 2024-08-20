provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "sandbox"
      Service     = "sample-app"
      CreatedFrom = "github.com/brcz/aws-tf-sample"
      CreatedBy   = "Terraform"
    }
  }
}

provider "local" {}

provider "null" {}

provider "tls" {}

provider "random" {}
