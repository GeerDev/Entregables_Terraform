# ─────────────────────────────────────────────
# PUNTO 7: Output con la IP pública de la instancia
# ─────────────────────────────────────────────

output "instance_public_ip" {
  description = "IP pública de la instancia EC2"
  value       = aws_instance.main.public_dns
}

output "ami_id" {
  description = "Ami ID utilizada para la instancia EC2"
  value = data.aws_ami.amazon_linux.arn
}
