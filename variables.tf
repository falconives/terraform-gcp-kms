variable "name" {
  description = "Name of the key"
  type        = string
  default     = "testkey"
}

variable "project" {
  description = "Project ID"
  type        = string
}
variable "location" {
  description = "Location/region of key ring and key"
  type        = string
}

variable "labels" {
  description = "Labels"
  type        = map(string)
  default     = {}
}

variable "encrypters" {
  description = "Members allowed to encrypt using this key"
  type        = list(string)
  default     = []
}

variable "decrypters" {
  description = "Members allowed to decrypt using this key"
  type        = list(string)
  default     = []
}

variable "services" {
  type    = list(string)
  default = []
}