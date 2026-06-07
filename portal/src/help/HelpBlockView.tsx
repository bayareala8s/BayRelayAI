import { Link } from "react-router-dom";
import type { HelpBlock } from "../help/types";

export function HelpBlockView({ block }: { block: HelpBlock }) {
  switch (block.type) {
    case "p":
      return <p className="help-text">{block.text}</p>;
    case "h3":
      return <h3 className="help-h3">{block.text}</h3>;
    case "ul":
      return (
        <ul className="help-list">
          {block.items.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      );
    case "ol":
      return (
        <ol className="help-list help-list-ordered">
          {block.items.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ol>
      );
    case "note":
      return (
        <aside className="help-note">
          {block.title && <strong>{block.title}: </strong>}
          {block.text}
        </aside>
      );
    case "route":
      return (
        <p className="help-route">
          <Link to={block.to} className="help-route-link">
            → {block.label}
          </Link>
        </p>
      );
    default:
      return null;
  }
}
