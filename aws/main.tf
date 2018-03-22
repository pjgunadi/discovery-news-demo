provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}
resource "aws_security_group" "default" {
  name        = "${var.instance_name}-secgrp"
  description = "${var.instance_name} Default Security Group"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    //cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_key_pair" "aws_public_key" {
  key_name   = "${var.key_pair_name}"
  public_key = "${file(var.public_key)}"
}

resource "aws_instance" "web" {
  instance_type = "t2.micro"
  ami = "${var.image_id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id = "${aws_subnet.default.id}"
  key_name = "${aws_key_pair.aws_public_key.id}"
  associate_public_ip_address = true
  tags {
    Name = "${var.instance_name}"
  }

}

resource "null_resource" "discovery_news" {
  connection {
    host = "${aws_instance.web.public_ip}"
    user = "ubuntu"
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
