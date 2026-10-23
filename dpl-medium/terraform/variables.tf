variable "vm_user_password_hash" {
  description = "sha512 hash du mdps super user des vms"
  type = string
  sensitive = true
}