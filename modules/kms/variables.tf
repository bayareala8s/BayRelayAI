variable "name_prefix" {
  type = string
}

variable "deletion_window_in_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
