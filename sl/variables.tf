variable ibm_bmx_api_key {
    description = "Bluemix API Key"
    default = ""
}
variable ibm_sl_username {
    description = "IBM Cloud Infrastructure Username"
    default = ""
}
variable ibm_sl_api_key {
    description = "IBM Cloud Infrastructure Password"
    default = ""
}
variable ssh_key_name {
    description = "SSH Public Key Label"
    default = "sl-test"
}
variable public_key {
    description = "SSH Public Key"
    default = "sl-test.pub"
}
variable private_key {
    description = "SSH Private Key"
    default = "sl-test"
}
variable "ssh_user" {
    description = "SSH User"
    default = "root"
}
variable datacenter {
    description = "Softlayer Data Center code"
    default = "dal13"
}
variable "domain" {
    description = "Instance Domain"
    default = "discovery-news.demo"
}
variable "os_reference" {
    description = "OS Reference Code: ubuntu: UBUNTU_16_64 Redhat: REDHAT_7_64"
    default = "UBUNTU_16_64"
}
variable "instance_prefix" {
    default = "icc"
}
variable "myinstance" {
  type = "map"
  default = {
    name        = "myinstance"
    cpu_cores   = "1"
    disk_size   = "25" // GB
    local_disk  = false
    memory      = "1024"
    network_speed = "100"
    private_network_only = false
    hourly_billing = true
  }
}
variable discovery_username {}
variable discovery_password {}