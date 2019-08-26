terraform {
  backend "s3" {
    bucket = "infra.danieljj.com"
    key    = "terraform/cluster.tfstate"
    region = "us-east-1"
  }
}

