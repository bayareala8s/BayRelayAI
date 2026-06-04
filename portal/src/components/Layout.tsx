import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { getUsername, logout } from "../auth";
import { appHomePath, isOperator, isPartner, useRole } from "../roleContext";
import { NavIcon, IconBell, IconSearch } from "./icons";
import SidebarBrand from "./SidebarBrand";
import {
  OPERATOR_NAV_MAIN,
  PARTNER_NAV_MAIN,
  NAV_HELP,
  type NavItem,
} from "../config/nav";

function userInitials(username: string | null): string {
  if (!username) return "?";
  const local = username.split("@")[0] || username;
  const parts = local.replace(/[^a-zA-Z]/g, " ").trim().split(/\s+/);
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return local.slice(0, 2).toUpperCase();
}

function SidebarNavItem({ item }: { item: NavItem }) {
  const isExternal = item.to.startsWith("http");
  const className = ({ isActive }: { isActive: boolean }) =>
    `sidebar-nav-link${isActive ? " sidebar-nav-link-active" : ""}`;

  const content = (
    <>
      <span className="sidebar-nav-icon">
        <NavIcon name={item.icon} />
      </span>
      <span className="sidebar-nav-label">{item.label}</span>
    </>
  );

  if (isExternal) {
    return (
      <a
        href={item.to}
        className="sidebar-nav-link"
        target="_blank"
        rel="noopener noreferrer"
      >
        {content}
      </a>
    );
  }

  return (
    <NavLink to={item.to} end={item.end} className={className}>
      {content}
    </NavLink>
  );
}

export default function Layout() {
  const navigate = useNavigate();
  const user = getUsername();
  const { role, partnerId, loading } = useRole();
  const navMain = isPartner(role) ? PARTNER_NAV_MAIN : OPERATOR_NAV_MAIN;
  const portalLabel = isPartner(role) ? "Partner portal" : "Operator portal";
  const displayName = user?.split("@")[0] || "User";
  const initials = userInitials(user);

  return (
    <div className="app-shell">
      <aside className="app-sidebar" aria-label="Main navigation">
        <div className="sidebar-top">
          <SidebarBrand portalLabel={portalLabel} homeTo={appHomePath(role)} />
        </div>

        <nav className="sidebar-nav" aria-label="Primary">
          {!loading &&
            navMain.map((item) => <SidebarNavItem key={item.to} item={item} />)}
        </nav>

        <div className="sidebar-bottom">
          <nav className="sidebar-nav sidebar-nav-secondary" aria-label="Support">
            <SidebarNavItem item={NAV_HELP} />
          </nav>
          <div className="sidebar-user-block">
            <p className="sidebar-user-email" title={user ?? undefined}>
              {user}
            </p>
            <button
              type="button"
              className="sidebar-signout"
              onClick={() => {
                logout();
                navigate("/login");
              }}
            >
              Sign out
            </button>
            <div className="sidebar-status-row">
              <span className="sidebar-status-dot" aria-hidden />
              <span className="sidebar-status-text">
                {isOperator(role) ? "Operator" : "Partner"}
                {partnerId ? ` · ${partnerId}` : ""}
              </span>
            </div>
          </div>
        </div>
      </aside>

      <div className="app-main-column">
        <header className="app-topbar">
          <div className="app-topbar-search" role="search">
            <IconSearch className="app-topbar-search-icon" />
            <span className="app-topbar-search-text">Search</span>
            <kbd className="app-topbar-kbd">⌘K</kbd>
          </div>
          <div className="app-topbar-actions">
            <button
              type="button"
              className="app-topbar-icon-btn"
              aria-label="Notifications"
              title="Notifications"
            >
              <IconBell />
            </button>
            <div className="app-topbar-user">
              <div className="app-topbar-avatar" aria-hidden>
                {initials}
              </div>
              <div className="app-topbar-user-text">
                <span className="app-topbar-user-name">{displayName}</span>
                <span className="app-topbar-user-role">{portalLabel}</span>
              </div>
            </div>
          </div>
        </header>

        <main className="app-main">
          <div className="app-main-inner">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
