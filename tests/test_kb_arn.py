"""Unit tests for Bedrock embedding / KB helper strings (mirrors modules/bedrock_vector_kb locals)."""


def bedrock_foundation_model_arn(region: str, model_id: str) -> str:
    rid = model_id.strip()
    reg = region.strip()
    return f"arn:aws:bedrock:{reg}::foundation-model/{rid}"


def test_embedding_arn_titan() -> None:
    assert bedrock_foundation_model_arn("us-west-2", "amazon.titan-embed-text-v1") == (
        "arn:aws:bedrock:us-west-2::foundation-model/amazon.titan-embed-text-v1"
    )


def test_embedding_arn_strips_whitespace() -> None:
    assert "amazon.titan-embed-text-v1" in bedrock_foundation_model_arn("eu-west-1", "  amazon.titan-embed-text-v1  ")
