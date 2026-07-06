# Nightly scheduled trigger for the recompute Lambda. Using EventBridge
# Scheduler (rather than a classic cron Lambda) demonstrates the
# "event-driven / scheduled pipeline" real-workload requirement, and
# decouples the batch scoring job from the request path entirely so
# request-time latency (the recommend Lambda) never depends on it.
resource "aws_scheduler_schedule" "nightly_recompute" {
  name       = "${var.project_name}-nightly-recompute-${var.environment}"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 3 * * ? *)" # 03:00 UTC daily

  target {
    arn      = aws_lambda_function.recompute.arn
    role_arn = var.lab_role_arn
  }
}

resource "aws_lambda_permission" "allow_scheduler_recompute" {
  statement_id  = "AllowEventBridgeSchedulerInvokeRecompute"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.recompute.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.nightly_recompute.arn
}
