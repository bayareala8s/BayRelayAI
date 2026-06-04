import { FormEvent, useState } from "react";
import { api } from "../api";
import {
  Alert,
  Card,
  Field,
  PageHeader,
} from "../components/ui";

type ChatLine = { role: "user" | "agent"; text: string };

const STARTER =
  "What is the policy for checksum failures and automatic retries?";

export default function AgentPage() {
  const [query, setQuery] = useState(STARTER);
  const [lines, setLines] = useState<ChatLine[]>([]);
  const [sessionId, setSessionId] = useState<string | undefined>();
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    const q = query.trim();
    if (!q) return;
    setError("");
    setLoading(true);
    setLines((prev) => [...prev, { role: "user", text: q }]);
    try {
      const res = await api.agentQuery(q, sessionId);
      if (res.session_id) setSessionId(res.session_id);
      setLines((prev) => [
        ...prev,
        { role: "agent", text: res.agent_response || "(No response)" },
      ]);
      setQuery("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Query failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <PageHeader
        title="Assistant"
        description="Ask questions about transfer policy and knowledge base content."
      />
      <Card>
        <div className="chat-panel">
          <div className="chat-messages">
            {lines.length === 0 && (
              <p className="empty-desc" style={{ margin: "1rem 0" }}>
                Responses are grounded in your configured Bedrock knowledge
                base.
              </p>
            )}
            {lines.map((line, i) => (
              <div
                key={i}
                className={`chat-bubble chat-bubble-${line.role}`}
              >
                <span className="chat-bubble-label">
                  {line.role === "user" ? "You" : "Assistant"}
                </span>
                {line.text}
              </div>
            ))}
          </div>
          <form className="chat-compose" onSubmit={onSubmit}>
            <Field label="Your question" htmlFor="agent-query">
              <textarea
                id="agent-query"
                rows={3}
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
            </Field>
            {error && <Alert variant="error">{error}</Alert>}
            <div className="form-actions">
              <button
                type="submit"
                className="btn btn-primary"
                disabled={loading}
              >
                {loading ? "Processing…" : "Send"}
              </button>
            </div>
          </form>
        </div>
      </Card>
    </>
  );
}
