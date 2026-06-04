type BrandProps = {
  subtitle?: string;
  compact?: boolean;
};

export default function Brand({ subtitle = "BayRelay Operator Portal", compact }: BrandProps) {
  return (
    <div className={`brand ${compact ? "brand-compact" : ""}`.trim()}>
      <img
        src="/bayrelay-icon.svg"
        alt="BayRelay"
        className="brand-icon"
        width={compact ? 36 : 44}
        height={compact ? 36 : 44}
      />
      <span className="brand-text">
        <span className="brand-name">BayAreaLa8s</span>
        <span className="brand-sub">{subtitle}</span>
      </span>
    </div>
  );
}
