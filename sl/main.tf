/*
provider "ibm" {
  bluemix_api_key    = "${var.ibm_bmx_api_key}"
  softlayer_username = "${var.ibm_sl_username}"
  softlayer_api_key  = "${var.ibm_sl_api_key}"
}
resource "ibm_compute_ssh_key" "sl_public_key" {
  label      = "${var.ssh_key_name}"
  public_key = "${file(var.public_key)}"
}

resource "ibm_compute_vm_instance" "discovery_news_instance" {
  datacenter           = "${var.datacenter}"
  domain               = "${var.domain}"
  hostname             = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.myinstance["name"]),count.index + 1) }"
  os_reference_code    = "${var.os_reference}"
  cores                = "${var.myinstance["cpu_cores"]}"
  memory               = "${var.myinstance["memory"]}"
  disks                = ["${split(" ",var.myinstance["disk_size"])}"]
  local_disk           = "${var.myinstance["local_disk"]}"
  network_speed        = "${var.myinstance["network_speed"]}"
  hourly_billing       = "${var.myinstance["hourly_billing"]}"
  private_network_only = "${var.myinstance["private_network_only"]}"
  ssh_key_ids = ["${ibm_compute_ssh_key.sl_public_key.id}"]
}
*/

provider "softlayer" {
  username = "${var.ibm_sl_username}"
  api_key  = "${var.ibm_sl_api_key}"
}
resource "softlayer_ssh_key" "sl_public_key" {
  name       = "${var.ssh_key_name}"
  public_key = "${file(var.public_key)}"
}

resource "softlayer_virtual_guest" "discovery_news_instance" {
  region               = "${var.datacenter}"
  domain               = "${var.domain}"
  name                 = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.myinstance["name"]),count.index + 1) }"
  image                = "${var.os_reference}"
  cpu                  = "${var.myinstance["cpu_cores"]}"
  ram                  = "${var.myinstance["memory"]}"
  disks                = ["${split(" ",var.myinstance["disk_size"])}"]
  local_disk           = "${var.myinstance["local_disk"]}"
  public_network_speed = "${var.myinstance["network_speed"]}"
  hourly_billing       = "${var.myinstance["hourly_billing"]}"
  private_network_only = "${var.myinstance["private_network_only"]}"
  ssh_keys             = ["${softlayer_ssh_key.sl_public_key.id}"]
}

resource "null_resource" "discovery_news" {
  connection {
    #host = "${ibm_compute_vm_instance.discovery_news_instance.ipv4_address}"
    host = "${softlayer_virtual_guest.discovery_news_instance.ipv4_address}"
    user = "root"
    #private_key = "${var.private_key}"    
    private_key = "${file(var.private_key)}"
  }

  provisioner "local-exec" {
    command = "cd ../ && tar --exclude=app/node_modules --exclude=app/build -czvf app.tar.gz app"
  }

  provisioner "file" {
    source      = "${path.module}/../app.tar.gz"
    destination = "/tmp/app.tar.gz"
  }

  provisioner "file" {
    content = <<EOF
#!/bin/bash -v
APP="app"
NODEJS_PATH="/nodejs/$APP"
DISCOVERY_USERNAME="${var.discovery_username}"
DISCOVERY_PASSWORD="${var.discovery_password}"
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common git
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt-get update
sudo apt-get install -y nodejs build-essential
mkdir -p $NODEJS_PATH
tar -zxvf /tmp/app.tar.gz -C /nodejs
cd $NODEJS_PATH
echo "DISCOVERY_USERNAME=$DISCOVERY_USERNAME" | tee .env
echo "DISCOVERY_PASSWORD=$DISCOVERY_PASSWORD" | tee -a .env
npm install
npm run build
echo "#!/bin/bash" | tee /usr/bin/startnodejs.sh
echo "cd $NODEJS_PATH" | tee -a /usr/bin/startnodejs.sh
echo "node server.js" | tee -a /usr/bin/startnodejs.sh
chmod +x /usr/bin/startnodejs.sh
EOF
    destination = "/tmp/deploy.sh"
  }

  provisioner "file" {
    content = <<EOF
[Service]
ExecStart=/usr/bin/startnodejs.sh
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=discovery-news

[Install]
WantedBy=multi-user.target
EOF
    destination = "/tmp/node-app.service"
  }

  # Execute the script remotely
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/deploy.sh; sudo bash /tmp/deploy.sh",
      "sudo cp /tmp/node-app.service /etc/systemd/system/",
      "sudo systemctl enable node-app",
      "sudo systemctl start node-app"
    ]
  }
}