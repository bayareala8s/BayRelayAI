import { getPortalConfig } from "./config";

const TOKEN_KEY = "bayrelay_id_token";
const USER_KEY = "bayrelay_username";

export function getToken(): string | null {
  return sessionStorage.getItem(TOKEN_KEY);
}

export function getUsername(): string | null {
  return sessionStorage.getItem(USER_KEY);
}

export function isLoggedIn(): boolean {
  return Boolean(getToken());
}

export type IdTokenClaims = {
  sub: string;
  email: string | null;
  partnerId: string | null;
  groups: string[];
};

export function parseIdToken(token: string): IdTokenClaims {
  try {
    const payload = token.split(".")[1];
    const json = JSON.parse(atob(payload.replace(/-/g, "+").replace(/_/g, "/")));
    const rawGroups = json["cognito:groups"];
    let groups: string[] = [];
    if (Array.isArray(rawGroups)) groups = rawGroups.map(String);
    else if (typeof rawGroups === "string") groups = [rawGroups];
    const partnerId =
      (json["custom:partner_id"] as string) || (json.partner_id as string) || null;
    return {
      sub: String(json.sub || ""),
      email: (json.email as string) || (json["cognito:username"] as string) || null,
      partnerId: partnerId?.trim() || null,
      groups,
    };
  } catch {
    return { sub: "", email: null, partnerId: null, groups: [] };
  }
}

export function logout(): void {
  sessionStorage.removeItem(TOKEN_KEY);
  sessionStorage.removeItem(USER_KEY);
}

export async function login(username: string, password: string): Promise<void> {
  const { cognitoRegion, cognitoClientId } = getPortalConfig();
  const res = await fetch(`https://cognito-idp.${cognitoRegion}.amazonaws.com/`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-amz-json-1.1",
      "X-Amz-Target": "AWSCognitoIdentityProviderService.InitiateAuth",
    },
    body: JSON.stringify({
      AuthFlow: "USER_PASSWORD_AUTH",
      ClientId: cognitoClientId,
      AuthParameters: {
        USERNAME: username,
        PASSWORD: password,
      },
    }),
  });

  const data = (await res.json()) as {
    AuthenticationResult?: { IdToken?: string };
    message?: string;
    __type?: string;
  };

  if (!res.ok || !data.AuthenticationResult?.IdToken) {
    const msg = data.message || data.__type || "Login failed";
    throw new Error(msg);
  }

  sessionStorage.setItem(TOKEN_KEY, data.AuthenticationResult.IdToken);
  sessionStorage.setItem(USER_KEY, username);
}
