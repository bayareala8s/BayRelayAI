import { useEffect, useMemo, useState } from "react";
import { useLocation } from "react-router-dom";
import {
  HELP_CATEGORIES,
  HELP_SECTIONS,
  filterHelpSections,
} from "../help/content";
import { HelpBlockView } from "../help/HelpBlockView";
import type { HelpSection } from "../help/types";
import { PageHeader } from "../components/ui";
import { isOperator, useRole } from "../roleContext";

function sectionAnchor(id: string): string {
  return `#${id}`;
}

export default function HelpPage() {
  const { role, loading } = useRole();
  const location = useLocation();
  const [query, setQuery] = useState("");
  const audience = isOperator(role) ? "operator" : "partner";

  const sections = useMemo(
    () => filterHelpSections(HELP_SECTIONS, audience, query),
    [audience, query],
  );

  const categories = useMemo(() => {
    const ids = new Set(sections.map((s) => s.category));
    return HELP_CATEGORIES.filter((c) => ids.has(c.id));
  }, [sections]);

  useEffect(() => {
    if (!location.hash) return;
    const id = location.hash.slice(1);
    const el = document.getElementById(id);
    if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [location.hash, sections]);

  return (
    <>
      <PageHeader
        title="Help center"
        description="Detailed guides for every area of the BayRelay operator and partner portal. Search topics or browse by category."
      />

      <div id="help-top" className="help-toolbar">
        <label className="help-search-label" htmlFor="help-search">
          Search help
        </label>
        <input
          id="help-search"
          type="search"
          className="help-search-input"
          placeholder="Search transfers, onboarding, policies, troubleshooting…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        {!loading && (
          <span className="help-audience-badge">
            Showing guides for{" "}
            <strong>{isOperator(role) ? "operators" : "partners"}</strong>
          </span>
        )}
      </div>

      <div className="help-layout">
        <nav className="help-toc" aria-label="Help topics">
          {categories.map((cat) => {
            const catSections = sections.filter((s) => s.category === cat.id);
            if (catSections.length === 0) return null;
            return (
              <div key={cat.id} className="help-toc-group">
                <p className="help-toc-category">{cat.label}</p>
                <ul>
                  {catSections.map((s) => (
                    <li key={s.id}>
                      <a href={sectionAnchor(s.id)} className="help-toc-link">
                        {s.title}
                      </a>
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </nav>

        <div className="help-content">
          {sections.length === 0 ? (
            <div className="help-empty card">
              <p>No topics match your search. Try &quot;transfer&quot;, &quot;onboarding&quot;, or &quot;audit&quot;.</p>
            </div>
          ) : (
            sections.map((s) => <HelpSectionCard key={s.id} section={s} />)
          )}

          <footer className="help-footer card">
            <h2 className="help-footer-title">Need more help?</h2>
            <p>
              For BayRelay implementation, production cutover, or AWS deployment
              questions, contact{" "}
              <a href="mailto:himanshu.bhadra@bayareala8s.com">
                himanshu.bhadra@bayareala8s.com
              </a>{" "}
              or visit{" "}
              <a
                href="https://www.bayareala8s.com/"
                target="_blank"
                rel="noopener noreferrer"
              >
                bayareala8s.com
              </a>
              .
            </p>
            <p className="muted">
              Include your <span className="mono">request_id</span>,{" "}
              <span className="mono">correlation_id</span>, and screenshots from
              Transfer detail or Audit log when reporting incidents.
            </p>
          </footer>
        </div>
      </div>
    </>
  );
}

function HelpSectionCard({ section }: { section: HelpSection }) {
  const catLabel =
    HELP_CATEGORIES.find((c) => c.id === section.category)?.label ??
    section.category;

  return (
    <article id={section.id} className="help-section card">
      <header className="help-section-header">
        <span className="help-section-category">{catLabel}</span>
        <h2 className="help-section-title">{section.title}</h2>
        <p className="help-section-summary">{section.summary}</p>
      </header>
      <div className="help-section-body">
        {section.blocks.map((block, i) => (
          <HelpBlockView key={`${section.id}-${i}`} block={block} />
        ))}
      </div>
      <p className="help-back-top">
        <a href="#help-top">Back to top</a>
      </p>
    </article>
  );
}
