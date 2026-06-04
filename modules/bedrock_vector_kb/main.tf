locals {
  # OpenSearch Serverless collection names: [a-z][a-z0-9-]{2,31}
  collection_name = substr(lower(replace("${var.name_prefix}-vs", "_", "-")), 0, 32)
  embedding_arn   = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.embedding_model_id}"
}

resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${local.collection_name}-enc"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/${local.collection_name}"
        ]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${local.collection_name}-net"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "dashboard"
          Resource = [
            "collection/${local.collection_name}"
          ]
        },
        {
          ResourceType = "collection"
          Resource = [
            "collection/${local.collection_name}"
          ]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_iam_role" "knowledge_base" {
  name = "${var.name_prefix}-bedrock-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${var.aws_account_id}:knowledge-base/*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_opensearchserverless_access_policy" "data" {
  name = "${local.collection_name}-data"
  type = "data"
  # AOSS requires separate Rules per ResourceType; index vs collection permissions are not mixable.
  policy = jsonencode([
    {
      Description = "Bedrock KB collection data for ${local.collection_name}"
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${local.collection_name}"
          ]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        }
      ]
      Principal = concat(
        [aws_iam_role.knowledge_base.arn],
        var.opensearch_data_access_principal_arns
      )
    },
    {
      Description = "Bedrock KB index for ${local.collection_name}"
      Rules = [
        {
          ResourceType = "index"
          Resource = [
            "index/${local.collection_name}/*"
          ]
          Permission = [
            "aoss:ReadDocument",
            "aoss:WriteDocument",
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:RestoreSnapshot",
            "aoss:DescribeSnapshot"
          ]
        }
      ]
      Principal = concat(
        [aws_iam_role.knowledge_base.arn],
        var.opensearch_data_access_principal_arns
      )
    }
  ])

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
  ]
}

resource "aws_opensearchserverless_collection" "vector" {
  name = local.collection_name
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data,
  ]
}

resource "null_resource" "bedrock_kb_vector_index" {
  triggers = {
    collection_endpoint = aws_opensearchserverless_collection.vector.collection_endpoint
    dimension           = var.embedding_vector_dimension
  }

  provisioner "local-exec" {
    command = <<-EOT
      if [ -x "${path.root}/../../.venv/bin/python3" ]; then PY="${path.root}/../../.venv/bin/python3"; else PY=python3; fi
      "$PY" "${path.module}/../../scripts/aoss_create_kb_index.py" \
        --endpoint "${aws_opensearchserverless_collection.vector.collection_endpoint}" \
        --region "${var.aws_region}" \
        --dimension ${var.embedding_vector_dimension}
    EOT
  }

  depends_on = [aws_opensearchserverless_collection.vector]
}

resource "aws_iam_role_policy" "knowledge_base" {
  name = "${var.name_prefix}-bedrock-kb-inline"
  role = aws_iam_role.knowledge_base.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadKbSource"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.kb_bucket_arn,
          "${var.kb_bucket_arn}/*"
        ]
      },
      {
        Sid      = "KmsForKbBucket"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = var.kb_kms_key_arn
      },
      {
        Sid    = "EmbedModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = local.embedding_arn
      },
      {
        Sid    = "OpenSearchServerless"
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = aws_opensearchserverless_collection.vector.arn
      }
    ]
  })
}

resource "aws_s3_object" "seed_document" {
  bucket       = var.kb_bucket_id
  key          = "runbooks/retry-policy.md"
  content      = file("${path.module}/assets/retry-policy.md")
  content_type = "text/markdown"
  kms_key_id   = var.kb_kms_key_arn
}

resource "aws_bedrockagent_knowledge_base" "this" {
  name     = "${var.name_prefix}-vector-kb"
  role_arn = aws_iam_role.knowledge_base.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_arn
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.vector.arn
      vector_index_name = "bedrock-knowledge-base-default-index"
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.knowledge_base,
    aws_opensearchserverless_collection.vector,
    null_resource.bedrock_kb_vector_index,
  ]

  tags = var.tags
}

resource "aws_bedrockagent_data_source" "s3" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.this.id
  name              = "${var.name_prefix}-kb-s3-source"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.kb_bucket_arn
    }
  }

  depends_on = [
    aws_bedrockagent_knowledge_base.this,
    aws_s3_object.seed_document,
  ]
}

# Ingestion is not a supported Terraform resource in aws provider 6.x; run
# scripts/start_kb_ingestion.py (or the demo) after apply once the data source exists.

resource "aws_bedrockagent_agent_knowledge_base_association" "agent" {
  agent_id             = var.agent_id
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  description          = "Operator runbooks and transfer policies"
  knowledge_base_state = "ENABLED"

  depends_on = [aws_bedrockagent_data_source.s3]
}

# Agent runtime queries the KB using the agent resource role — it must allow Retrieve.
resource "aws_iam_role_policy" "agent_kb_retrieve" {
  name = "${var.name_prefix}-agent-kb-retrieve"
  role = var.bedrock_agent_execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "QueryAttachedKnowledgeBase"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:GetKnowledgeBase"
        ]
        Resource = aws_bedrockagent_knowledge_base.this.arn
      }
    ]
  })

  depends_on = [
    aws_bedrockagent_knowledge_base.this,
    aws_bedrockagent_agent_knowledge_base_association.agent,
  ]
}

variable "name_prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "kb_bucket_id" {
  type = string
}

variable "kb_bucket_arn" {
  type = string
}

variable "kb_kms_key_arn" {
  type = string
}

variable "embedding_model_id" {
  type        = string
  default     = "amazon.titan-embed-text-v1"
  description = "Bedrock embedding model ID in this region (must be enabled in the account)."
}

variable "embedding_vector_dimension" {
  type        = number
  default     = 1536
  description = "Vector size for the OpenSearch knn index (Titan embed v1 = 1536; v2 = 1024)."
}

variable "agent_id" {
  type        = string
  description = "Bedrock agent ID (module.bedrock_agent.agent_id) to attach this knowledge base to."
}

variable "bedrock_agent_execution_role_name" {
  type        = string
  description = "Bedrock agent execution IAM role name (module.bedrock_agent.execution_role_name) for bedrock:Retrieve on this KB."
}

variable "opensearch_data_access_principal_arns" {
  type        = list(string)
  default     = []
  description = "Extra IAM principal ARNs for OpenSearch Serverless data access (e.g. account root for console debugging)."
}

output "knowledge_base_id" {
  value       = aws_bedrockagent_knowledge_base.this.id
  description = "Pass to scripts/test_retrieval.py as KNOWLEDGE_BASE_ID."
}

output "data_source_id" {
  value       = aws_bedrockagent_data_source.s3.data_source_id
  description = "S3 data source ID for StartIngestionJob."
}

output "opensearch_collection_name" {
  value       = aws_opensearchserverless_collection.vector.name
  description = "OpenSearch Serverless vector collection name."
}

output "opensearch_collection_arn" {
  value = aws_opensearchserverless_collection.vector.arn
}

output "knowledge_base_role_arn" {
  value = aws_iam_role.knowledge_base.arn
}
