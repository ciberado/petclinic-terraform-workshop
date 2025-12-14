output "ec2_global_ips" {
  description = "Public IP of the PetClinic server"
  value       = ["${aws_instance.app.*.public_ip}"]
}