// No third-party SDK or private token is shipped to the client. Apple returns
// the identity token over its authenticated HTTPS token endpoint; its subject
// must match an Apple identity independently verified by our Auth service.
export interface Config {
  authUrl: string;
  restUrl: string;
  serviceKey: string;
  teamId: string;
  clientId: string;
  keyId: string;
  privateKey: string;
  encryptionKey: string;
}
type Transport = typeof fetch;
class Failure extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string) { super(code); this.status = status; this.code = code; }
}
const encoder = new TextEncoder();
export function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function decode(value: string): Uint8Array {
  const base = value.replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(base), c => c.charCodeAt(0));
}
async function cipherKey(config: Config): Promise<CryptoKey> {
  const bytes = decode(config.encryptionKey);
  if (bytes.length !== 32) throw new Failure(503, "apple_not_configured");
  return crypto.subtle.importKey("raw", bytes, "AES-GCM", false, ["encrypt", "decrypt"]);
}
export async function seal(token: string, context: string, config: Config): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv, additionalData: encoder.encode(context) },
    await cipherKey(config), encoder.encode(token));
  return `v1.${base64url(iv)}.${base64url(new Uint8Array(ciphertext))}`;
}
export async function unseal(value: string, context: string, config: Config): Promise<string> {
  const [version, iv, ciphertext, extra] = value.split(".");
  if (version !== "v1" || !iv || !ciphertext || extra) throw new Failure(503, "apple_token_unavailable");
  return new TextDecoder().decode(await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: decode(iv), additionalData: encoder.encode(context) },
    await cipherKey(config), decode(ciphertext)));
}
async function clientSecret(config: Config): Promise<string> {
  if (!config.keyId || !config.privateKey || !config.teamId || !config.clientId) {
    throw new Failure(503, "apple_not_configured");
  }
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(encoder.encode(JSON.stringify({ alg: "ES256", kid: config.keyId })));
  const payload = base64url(encoder.encode(JSON.stringify({ iss: config.teamId, iat: now, exp: now + 300,
    aud: "https://appleid.apple.com", sub: config.clientId })));
  const key = await crypto.subtle.importKey("pkcs8", decode(config.privateKey.replace(/-----[^-]+-----/g, "").replace(/\s/g, "")),
    { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoder.encode(`${header}.${payload}`));
  return `${header}.${payload}.${base64url(new Uint8Array(signature))}`;
}
export function createHandler(config: Config, transport: Transport = fetch) {
  const request = (url: string, init: RequestInit = {}) => transport(url,
    { ...init, signal: AbortSignal.timeout(15000), redirect: "error" });
  const adminHeaders = { apikey: config.serviceKey, Authorization: `Bearer ${config.serviceKey}`, "Content-Type": "application/json" };
  return async (incoming: Request): Promise<Response> => {
    const response = (body: object, status = 200) => Response.json(body, { status,
      headers: { "Cache-Control": "no-store", "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS" } });
    try {
      if (incoming.method === "OPTIONS") return response({});
      if (incoming.method !== "POST") return response({ error: "method_not_allowed" }, 405);
      const authorization = incoming.headers.get("Authorization") ?? "";
      if (!/^Bearer [A-Za-z0-9._-]+$/.test(authorization)) throw new Failure(401, "not_authenticated");
      const userResponse = await request(`${config.authUrl}/user`, { headers: { apikey: config.serviceKey, Authorization: authorization } });
      if (!userResponse.ok) throw new Failure(401, "not_authenticated");
      const user = await userResponse.json();
      if (typeof user.id !== "string" || !/^[0-9a-f-]{36}$/i.test(user.id)) throw new Failure(401, "not_authenticated");
      const text = await incoming.text();
      if (text.length > 8192) throw new Failure(413, "request_too_large");
      let body;
      try { body = JSON.parse(text); } catch { throw new Failure(400, "invalid_request"); }
      if (!body || !["retain", "delete"].includes(body.action)) throw new Failure(400, "invalid_action");
      const identities = (user.identities ?? []).filter((identity: { provider: string }) => identity.provider === "apple");
      const subjects = identities.map((identity: { identity_data?: { sub?: string }; id?: string }) => identity.identity_data?.sub ?? identity.id);
      const rowUrl = `${config.restUrl}/apple_revoke_tokens?user_id=eq.${encodeURIComponent(user.id)}`;
      if (body.action === "retain") {
        if (!subjects.length) throw new Failure(403, "apple_identity_required");
        if (typeof body.code !== "string" || !body.code || body.code.length > 4096) throw new Failure(400, "apple_code_required");
        const tokenResponse = await request("https://appleid.apple.com/auth/token", { method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ client_id: config.clientId, client_secret: await clientSecret(config),
            code: body.code, grant_type: "authorization_code" }) });
        if (!tokenResponse.ok) throw new Failure(502, "apple_exchange_failed");
        const tokens = await tokenResponse.json();
        const claims = JSON.parse(new TextDecoder().decode(decode(tokens.id_token.split(".")[1])));
        if (claims.iss !== "https://appleid.apple.com" || claims.aud !== config.clientId ||
          claims.exp <= Date.now() / 1000 || !subjects.includes(claims.sub)) {
          throw new Failure(403, "apple_identity_mismatch");
        }
        if (typeof tokens.refresh_token !== "string" || !tokens.refresh_token || tokens.refresh_token.length > 8192) {
          throw new Failure(502, "apple_token_unavailable");
        }
        const saved = await request(`${config.restUrl}/apple_revoke_tokens?on_conflict=user_id`, { method: "POST",
          headers: { ...adminHeaders, Prefer: "resolution=merge-duplicates,return=minimal" },
          body: JSON.stringify({ user_id: user.id, apple_sub: claims.sub,
            encrypted_token: await seal(tokens.refresh_token, `${user.id}:${claims.sub}`, config),
            token_version: crypto.randomUUID(),
            revoked_at: null, updated_at: new Date().toISOString() }) });
        if (!saved.ok) throw new Failure(503, "apple_token_storage_failed");
        return response({ retained: true });
      }
      const stored = await request(`${rowUrl}&select=apple_sub,encrypted_token,token_version`, { headers: adminHeaders });
      if (!stored.ok) throw new Failure(503, "apple_token_unavailable");
      const rows = await stored.json();
      if (subjects.length && rows.length !== 1) throw new Failure(409, "apple_reauthentication_required");
      // Also revoke a retained authorization after its Auth identity was
      // unlinked elsewhere. Removing an identity is not Apple revocation.
      if (rows.length === 1) {
        const row = rows[0];
        if (subjects.length && !subjects.includes(row.apple_sub)) throw new Failure(403, "apple_identity_mismatch");
        const token = await unseal(row.encrypted_token, `${user.id}:${row.apple_sub}`, config);
        const revoked = await request("https://appleid.apple.com/auth/revoke", { method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ client_id: config.clientId, client_secret: await clientSecret(config), token,
            token_type_hint: "refresh_token" }) });
        // Apple returns 200 for both newly and previously revoked tokens, so a
        // database failure after this point can safely retry the same revocation.
        if (!revoked.ok) throw new Failure(502, "apple_revocation_failed");
        const marked = await request(`${rowUrl}&token_version=eq.${encodeURIComponent(row.token_version)}`, { method: "PATCH",
          headers: { ...adminHeaders, Prefer: "return=representation" }, body: JSON.stringify({ revoked_at: new Date().toISOString() }) });
        if (!marked.ok || (await marked.json()).length !== 1) throw new Failure(503, "apple_revocation_record_failed");
      }
      // The existing transactional RPC preserves shared quests and refunds
      // pending duels. Its caller stays the verified user, never a body user ID.
      const deleted = await request(`${config.restUrl}/rpc/delete_my_account`, { method: "POST",
        headers: { apikey: config.serviceKey, Authorization: authorization, "Content-Type": "application/json" }, body: "{}" });
      if (!deleted.ok) throw new Failure(503, "account_deletion_failed");
      return response({ deleted: true });
    } catch (error) {
      // Do not return/log provider responses, codes, refresh tokens or JWTs.
      return response({ error: error instanceof Failure ? error.code : "account_service_unavailable" },
        error instanceof Failure ? error.status : 503);
    }
  };
}
