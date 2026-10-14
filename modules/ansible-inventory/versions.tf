terraform {
  required_version = ">= 1.10.0"

  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "= 1.5.0"
    }
  }
}
