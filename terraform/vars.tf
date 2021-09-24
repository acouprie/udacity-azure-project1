variable "resource_group" {
  description = "Name of the resource group, including the -rg"
  default     = "udacity-assignment2-rg"
  type        = string
}

variable "packer_resource_group" {
  description = "Name of the resource group where the packer image is"
  default     =  "udacity-assignment1-rg"
  type        = string
}

variable "prefix" {
  description = "The prefix which should be used for all resources in the resource group specified"
  default     = "udacity-pg"
  type        = string
}

variable "num_of_vms" {
  description = "Number of VM resources to create behind the load balancer"
  default     = 3
  type        = number
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default     = "West Europe"
  type        = string
}

variable "vm_password" {
  description = "The password of the virtual machines."
  default     = "Th151545tr0ngP455word"
  type        = string
}