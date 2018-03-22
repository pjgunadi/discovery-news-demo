output "address" {
  value = "http://${aws_instance.web.public_ip}:5000"
}
