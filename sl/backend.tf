terraform {
  backend "s3" {
    bucket = "${var.s3_bucket}"
    key    = "sl-discovery-news/terraform.tfstate"
    region = "${var.s3_region}"
    acl    = "private"
  }
}
