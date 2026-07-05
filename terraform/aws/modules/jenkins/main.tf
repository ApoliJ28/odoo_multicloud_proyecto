# Buscamos la última imagen oficial de Ubuntu 22.04 LTS
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# Cortafuegos (Security Group)
resource "aws_security_group" "jenkins_sg" {
  name        = "odoo-jenkins-sg"
  description = "Permitir SSH y acceso a la UI de Jenkins"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH para Ansible y Administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "Interfaz Web de Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida a Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Generamos una llave SSH dinámica para la instancia
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins_key_pair" {
  key_name   = "odoo-jenkins-key"
  public_key = tls_private_key.jenkins_key.public_key_openssh
}

# La máquina virtual (EC2)
resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium" 
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  key_name                    = aws_key_pair.jenkins_key_pair.key_name
  associate_public_ip_address = true

  tags = { Name = "odoo-jenkins-orchestrator" }

  # root_block_device {
  #   volume_size = 20 
  #   volume_type = "gp3"
  # }
}