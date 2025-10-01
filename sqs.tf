resource "aws_sqs_queue" "fcg_sqs" {
    name = each.value.sqs_queue_name
    for_each = {
      for ms in var.microservices_config : ms.key => ms
      if (
        lookup(ms, "sqs_user", null) != null && trim(ms.sqs_user, " ") != "" &&
        lookup(ms, "sqs_queue_name", null) != null && trim(ms.sqs_queue_name, " ") != ""
      )
    }
    fifo_queue = true
    content_based_deduplication = true
    message_retention_seconds = 345600
    visibility_timeout_seconds = 30
}