import type { NavIconName } from "../components/icons";

export type NavItem = {
  to: string;
  label: string;
  icon: NavIconName;
  end?: boolean;
};

export const OPERATOR_NAV_MAIN: NavItem[] = [
  { to: "/operations", label: "Operations", icon: "dashboard", end: true },
  { to: "/transfers", label: "Transfers", icon: "transfers" },
  { to: "/transfers/new", label: "New transfer", icon: "transfer-new" },
  { to: "/rules", label: "Automation", icon: "automation" },
  { to: "/onboarding", label: "Onboarding", icon: "onboarding" },
  { to: "/onboarding/new", label: "New customer", icon: "customer-new" },
  { to: "/partners", label: "Partners", icon: "partners" },
  { to: "/policies", label: "Policies", icon: "policies" },
  { to: "/audit", label: "Audit log", icon: "audit" },
  { to: "/agent", label: "Assistant", icon: "assistant" },
];

export const PARTNER_NAV_MAIN: NavItem[] = [
  { to: "/home", label: "Home", icon: "home", end: true },
  { to: "/transfers", label: "My transfers", icon: "transfers" },
  { to: "/transfers/new", label: "New transfer", icon: "transfer-new" },
  { to: "/onboarding/new", label: "Apply / onboard", icon: "customer-new" },
  { to: "/agent", label: "Assistant", icon: "assistant" },
];

export const NAV_HELP: NavItem = {
  to: "https://www.bayareala8s.com/",
  label: "Help",
  icon: "help",
};
