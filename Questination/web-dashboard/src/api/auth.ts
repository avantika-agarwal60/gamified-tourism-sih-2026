const TOKEN_KEY = "questination_token";
const REFRESH_TOKEN_KEY = "questination_refresh_token";
const USER_ID_KEY = "questination_user_id";

export function saveToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}
export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}
export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
  localStorage.removeItem(USER_ID_KEY);
}

export function saveRefreshToken(token: string) {
  localStorage.setItem(REFRESH_TOKEN_KEY, token);
}
export function getRefreshToken(): string | null {
  return localStorage.getItem(REFRESH_TOKEN_KEY);
}

export function saveUserId(userId: string) {
  localStorage.setItem(USER_ID_KEY, userId);
}
export function getUserId(): string | null {
  return localStorage.getItem(USER_ID_KEY);
}

// Decodes the JWT payload (does NOT verify the signature - just reads the data)
export function decodeToken(
  token: string
): { username: string; id: string; role: string; isActive: boolean } | null {
  try {
    const payload = token.split(".")[1];
    const decoded = atob(payload);
    return JSON.parse(decoded);
  } catch (err) {
    return null;
  }
}