terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

resource "aws_sfn_state_machine" "transfer_precheck" {
  name     = "${var.name_prefix}-sf-transfer-precheck"
  role_arn = var.sfn_role_arn

  definition = jsonencode({
    StartAt = "Precheck"
    States = {
      Precheck = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"            = "precheck_all"
          "correlation_id.$"     = "$.correlation_id"
          "request_id.$"         = "$.request_id"
          "execution_id.$"       = "$.execution_id"
          "transfer_type.$"      = "$.transfer_type"
          "partner_id.$"         = "$.partner_id"
          "source_endpoint_id.$" = "$.source_endpoint_id"
          "target_endpoint_id.$" = "$.target_endpoint_id"
          "payload.$"            = "$.payload"
        }
        ResultPath = "$.precheck"
        Next       = "PrecheckOk"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "Failed"
        }]
      }
      PrecheckOk = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.precheck.ok"
          BooleanEquals = true
          Next          = "StartChild"
        }]
        Default = "Failed"
      }
      StartChild = {
        Type     = "Task"
        Resource = "arn:aws:states:::states:startExecution.sync:2"
        Parameters = {
          "StateMachineArn.$" = "$.precheck.child_state_machine_arn"
          "Input.$"           = "$.precheck.child_input"
        }
        ResultPath = "$.childExecution"
        Next       = "Succeeded"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "Failed"
        }]
      }
      Succeeded = { Type = "Succeed" }
      Failed = {
        Type  = "Fail"
        Error = "TransferPrecheckFailed"
        Cause = "Precheck or child execution failed"
      }
    }
  })

  tags = var.tags
}

resource "aws_sfn_state_machine" "s3_to_s3" {
  name     = "${var.name_prefix}-sf-s3-to-s3"
  role_arn = var.sfn_role_arn

  definition = jsonencode({
    StartAt = "Verify"
    States = {
      Verify = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "s3_verify_source"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
          "payload.$"        = "$.payload"
        }
        ResultPath = "$.verify"
        Next       = "VerifyOk"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "MarkFailed"
        }]
      }
      VerifyOk = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.verify.ok"
          BooleanEquals = true
          Next          = "Copy"
        }]
        Default = "MarkFailed"
      }
      Copy = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "s3_copy"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
          "payload.$"        = "$.payload"
        }
        ResultPath = "$.copy"
        Next       = "CopyOk"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "MarkFailed"
        }]
      }
      CopyOk = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.copy.ok"
          BooleanEquals = true
          Next          = "MarkSuccess"
        }]
        Default = "MarkFailed"
      }
      MarkSuccess = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "update_execution_status"
          "status"           = "SUCCEEDED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        ResultPath = "$.upd"
        Next       = "Emit"
      }
      MarkFailed = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "update_execution_status"
          "status"           = "FAILED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        ResultPath = "$.upd"
        Next       = "EmitFailed"
      }
      Emit = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "emit_event"
          "status"           = "SUCCEEDED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        End = true
      }
      EmitFailed = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "emit_event"
          "status"           = "FAILED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        Next = "FailHard"
      }
      FailHard = {
        Type  = "Fail"
        Error = "S3ToS3Failed"
        Cause = "Verification or copy failed"
      }
    }
  })

  tags = var.tags
}

resource "aws_sfn_state_machine" "s3_to_sftp" {
  name     = "${var.name_prefix}-sf-s3-to-sftp"
  role_arn = var.sfn_role_arn

  definition = jsonencode({
    StartAt = "Verify"
    States = {
      Verify = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "s3_verify_source"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
          "payload.$"        = "$.payload"
        }
        ResultPath = "$.verify"
        Next       = "VerifyOk"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "MarkFailed"
        }]
      }
      VerifyOk = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.verify.ok"
          BooleanEquals = true
          Next          = "Send"
        }]
        Default = "MarkFailed"
      }
      Send = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "s3_to_sftp_send"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
          "payload.$"        = "$.payload"
        }
        ResultPath = "$.send"
        Next       = "SendOk"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "MarkFailed"
        }]
      }
      SendOk = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.send.ok"
          BooleanEquals = true
          Next          = "MarkSuccess"
        }]
        Default = "MarkFailed"
      }
      MarkSuccess = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "update_execution_status"
          "status"           = "SUCCEEDED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        ResultPath = "$.upd"
        Next       = "Emit"
      }
      MarkFailed = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "update_execution_status"
          "status"           = "FAILED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        ResultPath = "$.upd"
        Next       = "EmitFailed"
      }
      Emit = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "emit_event"
          "status"           = "SUCCEEDED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        End = true
      }
      EmitFailed = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "emit_event"
          "status"           = "FAILED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        Next = "FailHard"
      }
      FailHard = {
        Type  = "Fail"
        Error = "S3ToSftpFailed"
        Cause = "S3 to SFTP flow failed"
      }
    }
  })

  tags = var.tags
}

resource "aws_sfn_state_machine" "sftp_to_s3" {
  name     = "${var.name_prefix}-sf-sftp-to-s3"
  role_arn = var.sfn_role_arn

  definition = jsonencode({
    StartAt = "Retrieve"
    States = {
      Retrieve = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "sftp_retrieve_to_s3"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
          "payload.$"        = "$.payload"
        }
        ResultPath = "$.retrieve"
        Next       = "RetrieveOk"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "MarkFailed"
        }]
      }
      RetrieveOk = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.retrieve.ok"
          BooleanEquals = true
          Next          = "MarkSuccess"
        }]
        Default = "MarkFailed"
      }
      MarkSuccess = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "update_execution_status"
          "status"           = "SUCCEEDED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        ResultPath = "$.upd"
        Next       = "Emit"
      }
      MarkFailed = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "update_execution_status"
          "status"           = "FAILED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        ResultPath = "$.upd"
        Next       = "EmitFailed"
      }
      Emit = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "emit_event"
          "status"           = "SUCCEEDED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        End = true
      }
      EmitFailed = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "emit_event"
          "status"           = "FAILED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        Next = "FailHard"
      }
      FailHard = {
        Type  = "Fail"
        Error = "SftpToS3Failed"
        Cause = "SFTP to S3 retrieve failed"
      }
    }
  })

  tags = var.tags
}

resource "aws_sfn_state_machine" "sftp_to_sftp" {
  name     = "${var.name_prefix}-sf-sftp-to-sftp"
  role_arn = var.sfn_role_arn

  definition = jsonencode({
    StartAt = "Relay"
    States = {
      Relay = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "sftp_relay"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
          "payload.$"        = "$.payload"
        }
        ResultPath = "$.relay"
        Next       = "RelayOk"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "MarkFailed"
        }]
      }
      RelayOk = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.relay.ok"
          BooleanEquals = true
          Next          = "MarkSuccess"
        }]
        Default = "MarkFailed"
      }
      MarkSuccess = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "update_execution_status"
          "status"           = "SUCCEEDED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        ResultPath = "$.upd"
        Next       = "Emit"
      }
      MarkFailed = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "update_execution_status"
          "status"           = "FAILED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        ResultPath = "$.upd"
        Next       = "EmitFailed"
      }
      Emit = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "emit_event"
          "status"           = "SUCCEEDED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        End = true
      }
      EmitFailed = {
        Type     = "Task"
        Resource = var.workflow_lambda_arn
        Parameters = {
          "operation"        = "emit_event"
          "status"           = "FAILED"
          "correlation_id.$" = "$.correlation_id"
          "request_id.$"     = "$.request_id"
          "execution_id.$"   = "$.execution_id"
          "transfer_type.$"  = "$.transfer_type"
        }
        Next = "FailHard"
      }
      FailHard = {
        Type  = "Fail"
        Error = "SftpToSftpFailed"
        Cause = "SFTP relay failed"
      }
    }
  })

  tags = var.tags
}

variable "name_prefix" {
  type = string
}

variable "workflow_lambda_arn" {
  type = string
}

variable "sfn_role_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "precheck_arn" {
  value = aws_sfn_state_machine.transfer_precheck.arn
}

output "s3_to_s3_arn" {
  value = aws_sfn_state_machine.s3_to_s3.arn
}

output "s3_to_sftp_arn" {
  value = aws_sfn_state_machine.s3_to_sftp.arn
}

output "sftp_to_s3_arn" {
  value = aws_sfn_state_machine.sftp_to_s3.arn
}

output "sftp_to_sftp_arn" {
  value = aws_sfn_state_machine.sftp_to_sftp.arn
}
