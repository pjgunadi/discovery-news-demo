output "discovery_news_output" {
  #value = "http://${ibm_compute_vm_instance.discovery_news_instance.ipv4_address}:5000"
  value = "http://${softlayer_virtual_guest.discovery_news_instance.ipv4_address}:5000"
}
