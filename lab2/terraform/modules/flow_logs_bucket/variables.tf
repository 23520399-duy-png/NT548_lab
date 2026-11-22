variable "name" {
  description = "Tiền tố đặt tên cho tài nguyên"
  type        = string
}

variable "retention_days" {
  description = "Số ngày giữ log trước khi tự xoá"
  type        = number
  default     = 7

  validation {
    condition     = var.retention_days >= 1
    error_message = "retention_days phải >= 1."
  }
}
