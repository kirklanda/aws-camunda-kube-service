variable "namespace" {
  type = string
}

variable "application" {
  type = string
}

variable "cluster_name" {
  type = string
  default = "healthlab-cluster"
}

variable "region" {
  description = "The AWS region to use for the lab"
  default = "ap-southeast-2"
  type = string
}