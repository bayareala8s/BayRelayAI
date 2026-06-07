export type HelpAudience = "all" | "operator" | "partner";

export type HelpBlock =
  | { type: "p"; text: string }
  | { type: "h3"; text: string }
  | { type: "ul"; items: string[] }
  | { type: "ol"; items: string[] }
  | { type: "note"; title?: string; text: string }
  | { type: "route"; label: string; to: string };

export type HelpSection = {
  id: string;
  title: string;
  category: string;
  audience: HelpAudience;
  summary: string;
  blocks: HelpBlock[];
};

export type HelpCategory = {
  id: string;
  label: string;
};
