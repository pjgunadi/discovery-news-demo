terraform {
  backend "s3" {
    bucket = "${var.s3_bucket}"
    key    = "aws-discovery-news/terraform.tfstate"
    region = "${var.s3_region}"
    acl    = "private"
  }
}
