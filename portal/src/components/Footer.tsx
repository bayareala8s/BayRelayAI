export default function Footer() {
  return (
    <footer className="ba-footer">
      <div className="ba-footer-inner">
        <div className="ba-footer-grid">
          <div>
            <p className="ba-footer-title">BayAreaLa8s</p>
            <p className="ba-footer-sub">BayRelay Operator Portal</p>
            <p className="ba-footer-tagline">Innovate. Transform.</p>
            <a
              href="https://www.bayareala8s.com/"
              target="_blank"
              rel="noopener noreferrer"
              className="ba-footer-link"
            >
              Visit bayareala8s.com
            </a>
          </div>
          <div>
            <p className="ba-footer-heading">Operations</p>
            <ul className="ba-footer-list">
              <li>File transfer orchestration</li>
              <li>Partner & endpoint registry</li>
              <li>Bedrock policy assistant</li>
            </ul>
          </div>
          <div>
            <p className="ba-footer-heading">Contact</p>
            <a href="mailto:himanshu.bhadra@bayareala8s.com" className="ba-footer-link">
              himanshu.bhadra@bayareala8s.com
            </a>
            <a href="tel:+19257581117" className="ba-footer-link">
              +1 925-758-1117
            </a>
            <p className="ba-footer-meta">186 Cameo Drive, Livermore, CA 94550</p>
          </div>
        </div>
        <p className="ba-footer-copy">
          © {new Date().getFullYear()} BayAreaLa8s. All rights reserved.
        </p>
      </div>
    </footer>
  );
}
