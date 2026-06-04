terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}

data "aws_region" "current" {}

resource "aws_iam_role" "bedrock_agent" {
  name = "${var.name_prefix}-bedrock-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "bedrock.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_invoke_lambda" {
  name = "${var.name_prefix}-bedrock-invoke-action-groups"
  role = aws_iam_role.bedrock_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.agent_tools_lambda_arn
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_bedrockagent_agent" "orchestrator" {
  agent_name                  = "file-transfer-orchestrator-agent-${var.name_suffix}"
  agent_resource_role_arn     = aws_iam_role.bedrock_agent.arn
  foundation_model            = var.foundation_model
  instruction                 = file("${path.module}/instruction.txt")
  idle_session_ttl_in_seconds = 600
  prepare_agent               = var.prepare_agent

  tags = var.tags
}

resource "aws_lambda_permission" "bedrock_agent_tools" {
  statement_id  = "AllowBedrockInvokeAgentTools"
  action        = "lambda:InvokeFunction"
  function_name = var.agent_tools_function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.orchestrator.agent_arn
}

# Single action group stays under Bedrock's per-agent API count limit (consolidated tools).
resource "aws_bedrockagent_agent_action_group" "unified" {
  agent_id           = aws_bedrockagent_agent.orchestrator.agent_id
  agent_version      = "DRAFT"
  action_group_name  = "BayRelayUnifiedActions"
  action_group_state = "ENABLED"

  action_group_executor {
    lambda = var.agent_tools_lambda_arn
  }

  api_schema {
    payload = file("${path.module}/openapi/unified.json")
  }
}

# Bedrock rejects DeleteAgentActionGroup while state is ENABLED (409). Disable via Get+Update (see script) before delete.
# Destroy-time provisioner may only reference `self` (not other resources).
resource "null_resource" "bedrock_action_group_disable_on_destroy" {
  triggers = {
    action_group_id = aws_bedrockagent_agent_action_group.unified.action_group_id
    agent_id        = aws_bedrockagent_agent.orchestrator.agent_id
    region          = coalesce(aws_bedrockagent_agent_action_group.unified.region, data.aws_region.current.id)
  }

  depends_on = [aws_bedrockagent_agent_action_group.unified]

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      if [ -x "${path.module}/../../.venv/bin/python3" ]; then
        PY="${path.module}/../../.venv/bin/python3"
      else
        PY=python3
      fi
      "$PY" "${path.module}/scripts/disable_action_group.py" \
        --region "${self.triggers.region}" \
        --agent-id "${self.triggers.agent_id}" \
        --action-group-id "${self.triggers.action_group_id}"
    EOT
  }
}

variable "name_prefix" {
  type = string
}

variable "name_suffix" {
  type        = string
  description = "Short suffix for agent name uniqueness per env"
}

variable "foundation_model" {
  type    = string
  default = "anthropic.claude-sonnet-4-20250514-v1:0"
}

variable "agent_tools_lambda_arn" {
  type = string
}

variable "agent_tools_function_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "prepare_agent" {
  type        = bool
  default     = true
  description = "Call PrepareAgent after changes so a numbered agent_version exists for InvokeAgent and console aliases."
}

output "agent_id" {
  value = aws_bedrockagent_agent.orchestrator.agent_id
}

output "agent_arn" {
  value = aws_bedrockagent_agent.orchestrator.agent_arn
}

output "agent_version" {
  value       = aws_bedrockagent_agent.orchestrator.agent_version
  description = "Prepared agent version string (e.g. 1, 2, …)."
}

output "execution_role_name" {
  value       = aws_iam_role.bedrock_agent.name
  description = "IAM role used as agent_resource_role_arn; grant bedrock:Retrieve for knowledge bases."
}
