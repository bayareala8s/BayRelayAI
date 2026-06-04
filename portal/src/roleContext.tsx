import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { getToken, parseIdToken } from "./auth";

export type PortalRole = "operator" | "partner" | "unknown";

export type RoleState = {
  role: PortalRole;
  partnerId: string | null;
  email: string | null;
  groups: string[];
  loading: boolean;
  refresh: () => Promise<void>;
};

const RoleContext = createContext<RoleState | null>(null);

export function RoleProvider({ children }: { children: ReactNode }) {
  const [role, setRole] = useState<PortalRole>("unknown");
  const [partnerId, setPartnerId] = useState<string | null>(null);
  const [email, setEmail] = useState<string | null>(null);
  const [groups, setGroups] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    const token = getToken();
    if (!token) {
      setRole("unknown");
      setPartnerId(null);
      setEmail(null);
      setGroups([]);
      setLoading(false);
      return;
    }
    const claims = parseIdToken(token);
    const gs = claims.groups;
    let r: PortalRole = "unknown";
    // Match API auth_context.py: operators win; legacy users with no groups → operator.
    if (gs.includes("bayrelay-operators")) r = "operator";
    else if (gs.includes("bayrelay-partners")) r = "partner";
    else if (claims.sub) r = "operator";
    setRole(r);
    setPartnerId(claims.partnerId);
    setEmail(claims.email);
    setGroups(gs);
    setLoading(false);
  }, []);

  useEffect(() => {
    refresh().catch(() => setLoading(false));
  }, [refresh]);

  const value = useMemo(
    () => ({ role, partnerId, email, groups, loading, refresh }),
    [role, partnerId, email, groups, loading, refresh],
  );

  return <RoleContext.Provider value={value}>{children}</RoleContext.Provider>;
}

export function useRole(): RoleState {
  const ctx = useContext(RoleContext);
  if (!ctx) throw new Error("useRole requires RoleProvider");
  return ctx;
}

export function isOperator(role: PortalRole): boolean {
  return role === "operator";
}

export function isPartner(role: PortalRole): boolean {
  return role === "partner";
}

/** Authenticated app home (public marketing lives at `/`). */
export function appHomePath(role: PortalRole): string {
  return isOperator(role) ? "/operations" : "/home";
}
