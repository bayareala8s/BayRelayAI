import { Link } from "react-router-dom";

type MarketingBrandProps = {
  href?: string;
};

export default function MarketingBrand({ href = "/" }: MarketingBrandProps) {
  return (
    <Link to={href} className="marketing-brand">
      <img
        src="/bayrelay-icon.svg"
        alt=""
        className="marketing-brand-icon"
        width={36}
        height={36}
        aria-hidden
      />
      <span className="marketing-brand-text">
        <span className="marketing-brand-eyebrow">BayAreaLa8s</span>
        <span className="marketing-brand-name">BayRelay</span>
      </span>
    </Link>
  );
}
