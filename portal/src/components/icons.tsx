import type { ReactNode, SVGProps } from "react";

type IconProps = SVGProps<SVGSVGElement>;

function IconBase({ children, ...props }: IconProps & { children: React.ReactNode }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={20}
      height={20}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      {...props}
    >
      {children}
    </svg>
  );
}

export function IconDashboard(props: IconProps) {
  return (
    <IconBase {...props}>
      <rect x="3" y="3" width="7" height="7" rx="1" />
      <rect x="14" y="3" width="7" height="7" rx="1" />
      <rect x="3" y="14" width="7" height="7" rx="1" />
      <rect x="14" y="14" width="7" height="7" rx="1" />
    </IconBase>
  );
}

export function IconTransfers(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" />
    </IconBase>
  );
}

export function IconTransferNew(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M12 5v14M5 12h14" />
      <circle cx="12" cy="12" r="9" />
    </IconBase>
  );
}

export function IconAutomation(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
      <circle cx="12" cy="12" r="3" />
    </IconBase>
  );
}

export function IconOnboarding(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2" />
      <rect x="9" y="3" width="6" height="4" rx="1" />
      <path d="M9 12h6M9 16h4" />
    </IconBase>
  );
}

export function IconCustomerNew(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M19 8v6M22 11h-6" />
    </IconBase>
  );
}

export function IconPartners(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
    </IconBase>
  );
}

export function IconAssistant(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z" />
    </IconBase>
  );
}

export function IconHome(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M3 10.5L12 3l9 7.5V20a1 1 0 01-1 1h-5v-6H9v6H4a1 1 0 01-1-1v-9.5z" />
    </IconBase>
  );
}

export function IconHelp(props: IconProps) {
  return (
    <IconBase {...props}>
      <circle cx="12" cy="12" r="9" />
      <path d="M9.5 9a2.5 2.5 0 115 0c0 2-2.5 2-2.5 3.5" />
      <path d="M12 17h.01" />
    </IconBase>
  );
}

export function IconBell(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 01-3.46 0" />
    </IconBase>
  );
}

export function IconSearch(props: IconProps) {
  return (
    <IconBase {...props}>
      <circle cx="11" cy="11" r="7" />
      <path d="M20 20l-3-3" />
    </IconBase>
  );
}

export function IconSignOut(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9" />
    </IconBase>
  );
}

export function IconPolicy(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    </IconBase>
  );
}

export function IconAudit(props: IconProps) {
  return (
    <IconBase {...props}>
      <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
      <path d="M14 2v6h6M16 13H8M16 17H8M10 9H8" />
    </IconBase>
  );
}

export type NavIconName =
  | "dashboard"
  | "transfers"
  | "transfer-new"
  | "automation"
  | "onboarding"
  | "customer-new"
  | "partners"
  | "policies"
  | "audit"
  | "assistant"
  | "home"
  | "help";

const NAV_ICONS: Record<NavIconName, (p: IconProps) => ReactNode> = {
  dashboard: IconDashboard,
  transfers: IconTransfers,
  "transfer-new": IconTransferNew,
  automation: IconAutomation,
  onboarding: IconOnboarding,
  "customer-new": IconCustomerNew,
  partners: IconPartners,
  policies: IconPolicy,
  audit: IconAudit,
  assistant: IconAssistant,
  home: IconHome,
  help: IconHelp,
};

export function NavIcon({ name, ...props }: { name: NavIconName } & IconProps) {
  const C = NAV_ICONS[name];
  return <C {...props} />;
}
