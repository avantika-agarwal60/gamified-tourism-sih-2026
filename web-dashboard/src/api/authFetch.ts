import {
  getToken,
  getRefreshToken,
  saveToken,
  saveRefreshToken,
  clearToken,
} from "./auth";

const API_BASE = "https://questination-production-08b6.up.railway.app";

export async function authFetch(
  url: string,
  options: RequestInit = {}
): Promise<Response> {
  const token = getToken();
  const headers = {
    ...(options.headers || {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };

  let response = await fetch(url, { ...options, headers });

  // Expired JWTs can be returned as either 401 or 403 by the API.
  if ((response.status === 401 || response.status === 403) && getRefreshToken()) {
    const refreshtoken = getRefreshToken();

    const refreshResponse = await fetch(`${API_BASE}/auth/refreshtoken`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshtoken }),
    });

    if (refreshResponse.ok) {
      const data = await refreshResponse.json().catch(() => null);

      if (data?.token) {
        saveToken(data.token);
        if (data.refreshtoken) saveRefreshToken(data.refreshtoken);

        response = await fetch(url, {
          ...options,
          headers: {
            ...(options.headers || {}),
            Authorization: `Bearer ${data.token}`,
          },
        });
      }
    } else {
      clearToken();
    }
  }

  return response;
}
