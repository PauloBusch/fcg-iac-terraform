resource "aws_sqs_queue" "fcg_sqs" {
  name        = each.value.sqs_queue_name
  for_each    = { for ms in var.microservices_sqs_config : ms.key => ms }
  fifo_queue  = true
  content_based_deduplication = true
  message_retention_seconds = 345600
  visibility_timeout_seconds = 30
}