terraform {
  backend "s3" {
    bucket = "pgtf"
    key    = "aws-discovery-news/terraform.tfstate"
    region = "ap-southeast-1"
    acl    = "private"
  }
}
