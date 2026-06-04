export type PortalConfig = {
  apiUrl: string;
  cognitoRegion: string;
  cognitoClientId: string;
};

export function getPortalConfig(): PortalConfig {
  const apiUrl = (import.meta.env.VITE_API_URL || "").trim();
  const cognitoRegion = (import.meta.env.VITE_COGNITO_REGION || "").trim();
  const cognitoClientId = (import.meta.env.VITE_COGNITO_CLIENT_ID || "").trim();

  const missing: string[] = [];
  if (!apiUrl) missing.push("VITE_API_URL");
  if (!cognitoRegion) missing.push("VITE_COGNITO_REGION");
  if (!cognitoClientId) missing.push("VITE_COGNITO_CLIENT_ID");

  if (missing.length > 0) {
    throw new Error(
      `Portal misconfigured (missing ${missing.join(", ")}). Rebuild with ./scripts/build_portal.sh.`,
    );
  }

  return { apiUrl, cognitoRegion, cognitoClientId };
}
