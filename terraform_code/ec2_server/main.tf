terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.67.0"
    }
  }
}

provider "aws" {
  region = var.region_name
}

# STEP1: CREATE SECURITY GROUP
resource "aws_security_group" "my-sg" {
  name        = "JENKINS-SERVER-SG-1"
  description = "Security group for Jenkins, SonarQube, Grafana, and Prometheus"

  # Allow SSH Access
  ingress {
    description = "SSH Port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP & HTTPS Access
  ingress {
    description = "HTTP Port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS Port"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow Jenkins, SonarQube, Grafana, and Prometheus
  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# STEP2: CREATE EC2 INSTANCE
resource "aws_instance" "my-ec2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.my-sg.id]

  root_block_device {
    volume_size = var.volume_size
  }

  tags = {
    Name = var.server_name
  }

  # INSTALL & CONFIGURE SERVICES USING REMOTE-EXEC
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      private_key = file("panda.pem")
      user        = "ubuntu"
      host        = self.public_ip
    }

    inline = [
      "sudo apt update -y",
      "sudo apt install -y unzip wget curl docker.io",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker ubuntu",
      "sudo chmod 777 /var/run/docker.sock",

      # Install AWS CLI
      "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
      "unzip awscliv2.zip",
      "sudo ./aws/install",

      # Install & Run SonarQube
      "docker run -d --name sonar -p 9000:9000 sonarqube:lts-community",

      # Install & Run Jenkins
      "docker run -d --name jenkins -p 8080:8080 jenkins/jenkins:lts",

      # Install & Run Grafana
      "docker run -d --name grafana -p 3000:3000 grafana/grafana",

      # Install & Run Prometheus
      "mkdir -p /opt/prometheus",
      "sudo chmod 777 /opt/prometheus",
      "docker run -d --name prometheus -p 9090:9090 prom/prometheus",

      # Output Service URLs
      "ip=$(curl -s ifconfig.me)",
      "echo 'Access Jenkins Server here --> http://'$ip':8080'",
      "echo 'Access SonarQube Server here --> http://'$ip':9000'",
      "echo 'Access Grafana Server here --> http://'$ip':3000'",
      "echo 'Access Prometheus Server here --> http://'$ip':9090'",
    ]
  }
}

# STEP3: OUTPUT SERVER DETAILS
output "SERVER-SSH-ACCESS" {
  value = "ubuntu@${aws_instance.my-ec2.public_ip}"
}

output "PUBLIC-IP" {
  value = "${aws_instance.my-ec2.public_ip}"
}

output "PRIVATE-IP" {
  value = "${aws_instance.my-ec2.private_ip}"
}
