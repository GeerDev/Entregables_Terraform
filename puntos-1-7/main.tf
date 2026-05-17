# ─────────────────────────────────────────────
# PUNTO 1: VPC con acceso a Internet
# ─────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ─────────────────────────────────────────────
# PUNTO 2: Subnet pública con acceso a Internet
# ─────────────────────────────────────────────

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────────
# PUNTO 3: Security Group
# ─────────────────────────────────────────────

resource "aws_security_group" "main" {
  name        = "${var.project_name}-sg"
  description = "Permite HTTP desde cualquier IP y SSH solo desde mi IP"
  vpc_id      = aws_vpc.main.id

  # Puerto 80 abierto para todo el mundo (HTTP)
  ingress {
    description = "HTTP desde cualquier IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto 22 solo desde tu IP (SSH)
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

  # Todo el tráfico de salida permitido (necesario para descargar paquetes, Docker, etc.)
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

# Terraform no genera el par de claves, solo sube la clave pública a AWS.
# La clave privada (~/.ssh/id_rsa) se queda en tu máquina y nunca sale de ella.
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

# Consulta dinámica a AWS para obtener la última AMI de Amazon Linux 2023
# Funciona en cualquier región sin hardcodear el ID
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
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.main.id]
  key_name               = aws_key_pair.main.key_name

  # ─────────────────────────────────────────────
  # PUNTO 6: Instalar Docker al arrancar la instancia
  # ─────────────────────────────────────────────
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
  EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }
}
