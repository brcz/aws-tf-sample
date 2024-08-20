#region Create SQS Queue
resource "aws_sqs_queue" "sample_app" {
  name                    = local.sample_app_sqs_name
  sqs_managed_sse_enabled = true
}

# Define Access policy document for the  SQS Queue
data "aws_iam_policy_document" "sample_app" {
  statement {
    effect    = "Allow"
    resources = [aws_sqs_queue.sample_app.arn]
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueueTags",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
    ]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
  }
}

# Set Access policy document for the  SQS Queue
resource "aws_sqs_queue_policy" "sample_app" {
  queue_url = aws_sqs_queue.sample_app.id
  policy    = data.aws_iam_policy_document.sample_app.json
}
#endregion
