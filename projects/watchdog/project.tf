

resource "aws_cloudwatch_event_rule" "console" {
  name        = "capture-sechubevents"
  description = "Capture all Security Hub Findings"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.securityhub"
  ],
  "detail-type": [
    "Security Hub Findings - Imported"
    
  ]
}
PATTERN
}



resource "null_resource" "lambda_sechub_build" {
  triggers  ={
    handler      = "${base64sha256(file("projects/watchdog/lambda_sechub_to_sns/handler.py"))}"
    requirements = "${base64sha256(file("projects/watchdog/lambda_sechub_to_sns/requirements.txt"))}"
    build        = "${base64sha256(file("projects/watchdog/lambda_sechub_to_sns/build.sh"))}"
  }

  provisioner "local-exec" {
    command = "${path.module}/lambda_sechub_to_sns/build.sh"
  }
}
data "archive_file" "lambda_sechub" {
  source_dir  = "${path.module}/lambda_sechub_to_sns/"
  output_path = "${path.module}/lambda_sechub_to_sns.zip"
  type        = "zip"

  depends_on = ["null_resource.lambda_sechub_build"]
}

resource "aws_lambda_function" "lambda_sechub" {
  function_name    = "security_hub_to_sns"
  handler          = "handler.lambda_handler"
  role             = "${aws_iam_role.lambda_exec.arn}"
  runtime          = "python3.7"
  timeout          = 60
  filename         = "${data.archive_file.lambda_sechub.output_path}"
  source_code_hash = "${data.archive_file.lambda_sechub.output_base64sha256}"

  environment  {
    variables = {
      snscritical = "${aws_sns_topic.snscritical_topic.arn}"
      snshigh = "${aws_sns_topic.snshigh_topic.arn}"
    }
  }
}

resource "aws_sns_topic" "snscritical_topic" {
  name = "security-hub-indings-critical"
}


resource "aws_sns_topic" "snshigh_topic" {
  name = "security-hub-indings-high"
}

resource "aws_iam_role" "lambda_exec" {
  name = "securityhub_execution_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "lambda_filter" {
    rule = "${aws_cloudwatch_event_rule.console.name}"
    arn = "${aws_lambda_function.lambda_sechub.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.lambda_sechub.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.console.arn}"
}


resource "aws_iam_policy" "lambda_logging" {
  name = "securityhub_lambda_logging"
  path = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "sns:Publish"
      ],
      "Resource": 
      [
        "${aws_sns_topic.snshigh_topic.arn}",
        "${aws_sns_topic.snscritical_topic.arn}"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role = "${aws_iam_role.lambda_exec.name}"
  policy_arn = "${aws_iam_policy.lambda_logging.arn}"
}

# SCHEDULED

resource "null_resource" "lambda_sechub_scheduled_build" {
  triggers  ={
    handler      = "${base64sha256(file("projects/watchdog/lambda_scheduled/handler.py"))}"
    requirements = "${base64sha256(file("projects/watchdog/lambda_scheduled/requirements.txt"))}"
    build        = "${base64sha256(file("projects/watchdog/lambda_scheduled/build.sh"))}"
  }

  provisioner "local-exec" {
    command = "${path.module}/lambda_scheduled/build.sh"
  }
}

data "archive_file" "lambda_scheduled" {
  source_dir  = "${path.module}/lambda_scheduled/"
  output_path = "${path.module}/lambda_scheduled.zip"
  type        = "zip"

  depends_on = ["null_resource.lambda_sechub_scheduled_build"]
}

resource "aws_lambda_function" "lambda_scheduled" {
  function_name    = "security_hub_finding_simulator"
  handler          = "handler.lambda_handler"
  role             = "${aws_iam_role.lambda_scheduler_exec_role.arn}"
  runtime          = "python3.7"
  timeout          = 60
  filename         = "${data.archive_file.lambda_scheduled.output_path}"
  source_code_hash = "${data.archive_file.lambda_scheduled.output_base64sha256}"
}

resource "aws_iam_role_policy_attachment" "scheduled_lambda_policy" {
  role = "${aws_iam_role.lambda_scheduler_exec_role.name}"
  policy_arn = "${aws_iam_policy.lambda_scheduler_policy.arn}"
}


resource "aws_iam_role" "lambda_scheduler_exec_role" {
  name = "securityhub_scheduled_execution_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}



resource "aws_cloudwatch_log_group" "finding_simulator" {
  name = "/aws/lambda/security_hub_finding_simulator"

  retention_in_days = 7

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }

  tags = {
    environment = "production"
    team = "zdf"
    service = "watchdog"
  }
}

resource "aws_cloudwatch_log_group" "lambda_sechub" {
  name = "/aws/lambda/lambda_sechub"

  retention_in_days = 7

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }

  tags = {
    environment = "production"
    team = "zdf"
    service = "watchdog"
  }
}

resource "aws_iam_policy" "lambda_scheduler_policy" {
  name = "lamba_scheduler_policy"
  path = "/"
  description = "IAM policy for scheduler lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "securityhub:BatchImportFindings"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}