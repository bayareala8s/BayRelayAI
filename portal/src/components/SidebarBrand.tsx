import { Link } from "react-router-dom";

export default function SidebarBrand({
  portalLabel,
  homeTo = "/operations",
}: {
  portalLabel: string;
  homeTo?: string;
}) {
  return (
    <Link to={homeTo} className="sidebar-brand">
      <img
        src="/bayrelay-icon.svg"
        alt=""
        className="sidebar-brand-icon"
        width={40}
        height={40}
      />
      <span className="sidebar-brand-text">
        <span className="sidebar-brand-eyebrow">BayAreaLa8s</span>
        <span className="sidebar-brand-name">BayRelay</span>
        <span className="sidebar-brand-sub">{portalLabel}</span>
      </span>
    </Link>
  );
}
