# ECR Repository
data "aws_ecr_image" "sub_lambda_image_lookup" {
  repository_name = aws_ecr_repository.sub_lambda_image.name
  most_recent     = true
}

resource "aws_ecr_repository" "sub_lambda_image" {
  name         = "dsb-blogging-assistant-sub-lambda-image"
  force_delete = true
}

resource "aws_ecr_lifecycle_policy" "sub_lambda_image_lifecycle_policy" {
  repository = aws_ecr_repository.sub_lambda_image.name

  # https://docs.aws.amazon.com/AmazonECR/latest/userguide/lifecycle_policy_examples.html
  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep only one untagged image, expire all others",
            "selection": {
                "tagStatus": "untagged",
                "countType": "imageCountMoreThan",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
  EOF
}


# Lambda Function
resource "aws_iam_role" "sub_lambda_exec_role" {
  name = "dsb-ba-sub-lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
}

resource "aws_iam_role_policy" "read_only_policy" {
  name = "read_only_policy"
  role = aws_iam_role.sub_lambda_exec_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ec2:DescribeNetworkInterfaces"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_lambda_function" "sub_lambda_func" {
  function_name = "dsb-blogging-assistant-sub-lambda"
  role          = aws_iam_role.sub_lambda_exec_role.arn

  image_uri    = data.aws_ecr_image.sub_lambda_image_lookup.image_uri
  timeout      = 120 # 2 minutes
  package_type = "Image"

  environment {
    variables = {
      CLUSTER_NAME      = "${aws_ecs_cluster.default_ecs_cluster.name}"
      CALLBACK_TASK_ARN = "${aws_ecs_task_definition.poller_task.arn}"
      TOPIC_URL         = "https://www.youtube.com/xml/feeds/videos.xml?channel_id=UCZtelX2yGw6NVu7-imd6zHw"
    }
  }
  depends_on = [aws_ecr_repository.sub_lambda_image, aws_ecs_task_definition.poller_task]
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sub_lambda_func.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sub_lambda_event_rule.arn
}


# Eventbridge Rules
resource "aws_cloudwatch_event_rule" "sub_lambda_event_rule" {
  name                = "dsb-blogging-assistant-sub-lambda-event-rule"
  description         = "Trigger the lambda function every day"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "sub_lambda_event_target" {
  rule      = aws_cloudwatch_event_rule.sub_lambda_event_rule.name
  target_id = "dsb-blogging-assistant-sub-lambda-event-target"
  arn       = aws_lambda_function.sub_lambda_func.arn
}