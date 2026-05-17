# ─────────────────────────────────────────────
# PUNTO 8: Refactorización usando el VPC Module
# El módulo crea internamente: VPC, Internet Gateway,
# subnets públicas, route tables y sus asociaciones.
# ─────────────────────────────────────────────

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs            = ["${var.region}a"]
  public_subnets = [var.subnet_cidr]

  enable_nat_gateway      = false
  map_public_ip_on_launch = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.project_name
  }
}

# ─────────────────────────────────────────────
# PUNTO 3: Security Group
# ─────────────────────────────────────────────

resource "aws_security_group" "main" {
  name        = "${var.project_name}-sg"
  description = "Permite HTTP desde cualquier IP y SSH solo desde mi IP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP desde cualquier IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH solo desde mi IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.my_ip
  }

  # Puerto 22 desde EC2 Instance Connect (IPs de AWS eu-west-3)
  # Necesario para conectarse desde la consola web de AWS
  ingress {
    description = "SSH desde EC2 Instance Connect"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["35.180.112.80/29"]
  }

  egress {
    description = "Todo el trafico de salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ─────────────────────────────────────────────
# PUNTO 4: Key Pair para acceso SSH a EC2
# ─────────────────────────────────────────────

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-keypair"
  public_key = file(var.public_key_path)

  tags = {
    Name = "${var.project_name}-keypair"
  }
}

# ─────────────────────────────────────────────
# PUNTO 5: Instancia EC2 en la subnet pública
# ─────────────────────────────────────────────

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.main.id]
  key_name               = aws_key_pair.main.key_name

  # ─────────────────────────────────────────────
  # PUNTO 6: Instalar Docker al arrancar la instancia
  # ─────────────────────────────────────────────
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker
    dnf install -y docker ec2-instance-connect
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
  EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }
}
