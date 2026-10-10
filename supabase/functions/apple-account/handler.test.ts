import assert from "node:assert/strict";
import test from "node:test";
import { base64url, createHandler, seal, unseal, type Config } from "./handler.ts";

const userId = "10000000-0000-0000-0000-000000000001";
const subject = "apple-subject-a";
const encoder = new TextEncoder();
async function configuration(): Promise<Config> {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  return { authUrl: "http://auth", restUrl: "http://rest", serviceKey: "test-service",
    teamId: "test-team", clientId: "com.auraquest.auraQuest", keyId: "test-key",
    privateKey: `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----`,
    encryptionKey: base64url(crypto.getRandomValues(new Uint8Array(32))) };
}
function input(action = "delete", extra = {}) {
  return new Request("https://example.invalid/apple-account", { method: "POST",
    headers: { Authorization: "Bearer user-session" }, body: JSON.stringify({ action, ...extra }) });
}
function fixture(config: Config, options: { apple?: boolean; rows?: unknown[]; revokeStatus?: number;
  subject?: string; authStatus?: number; markRows?: unknown[]; deleteStatus?: number } = {}) {
  const calls: { url: string; init: RequestInit }[] = [];
  const transport: typeof fetch = async (url, init = {}) => {
    const address = String(url); calls.push({ url: address, init });
    if (address === "http://auth/user") return Response.json({ id: userId,
      identities: options.apple === false ? [] : [{ provider: "apple", identity_data: { sub: subject } }] },
      { status: options.authStatus ?? 200 });
    if (address.endsWith("/auth/token")) {
      const claims = { iss: "https://appleid.apple.com", aud: config.clientId,
        sub: options.subject ?? subject, exp: Math.floor(Date.now() / 1000) + 300 };
      return Response.json({ id_token: `header.${base64url(encoder.encode(JSON.stringify(claims)))}.signature`, refresh_token: "private-refresh-token" });
    }
    if (address.endsWith("/auth/revoke")) return new Response(null, { status: options.revokeStatus ?? 200 });
    if (address.endsWith("/rpc/delete_my_account")) return new Response(null, { status: options.deleteStatus ?? 200 });
    if (init.method === "POST") return new Response(null, { status: 201 });
    if (init.method === "PATCH") return Response.json(options.markRows ?? [{ user_id: userId }]);
    return Response.json(options.rows ?? []);
  };
  return { calls, handler: createHandler(config, transport) };
}
test("encrypted provider token is bound to its user/Apple subject and detects tampering", async () => {
  const config = await configuration();
  const ciphertext = await seal("private-refresh-token", "user-a:apple-a", config);
  assert.equal(ciphertext.includes("private-refresh-token"), false);
  assert.equal(await unseal(ciphertext, "user-a:apple-a", config), "private-refresh-token");
  await assert.rejects(() => unseal(ciphertext, "user-b:apple-a", config));
  await assert.rejects(() => unseal(ciphertext.slice(0, -8) + "AAAAAAAA", "user-a:apple-a", config));
});
test("missing or invalid user session never reaches Apple or the database", async () => {
  const config = await configuration();
  const missing = fixture(config);
  assert.equal((await missing.handler(new Request("https://example.invalid", { method: "POST", body: "{}" }))).status, 401);
  assert.equal(missing.calls.length, 0);
  const invalid = fixture(config, { authStatus: 401 });
  assert.equal((await invalid.handler(input())).status, 401);
  assert.equal(invalid.calls.length, 1);
});
test("another Apple subject cannot be retained for the signed-in user", async () => {
  const config = await configuration(); const { handler, calls } = fixture(config, { subject: "another-user" });
  assert.equal((await handler(input("retain", { code: "one-time-code" }))).status, 403);
  assert.equal(calls.some(call => call.url.includes("apple_revoke_tokens")), false);
});
test("retention exchanges a code then stores only an encrypted, user-bound token", async () => {
  const config = await configuration(); const { handler, calls } = fixture(config);
  assert.deepEqual(await (await handler(input("retain", { code: "one-time-code", user_id: "victim" }))).json(), { retained: true });
  const saved = JSON.parse(String(calls.at(-1)?.init.body));
  assert.equal(saved.user_id, userId);
  assert.equal(saved.apple_sub, subject);
  assert.equal(saved.revoked_at, null);
  assert.equal(await unseal(saved.encrypted_token, `${userId}:${subject}`, config), "private-refresh-token");
  const form = calls.find(call => call.url.endsWith("/auth/token"))!.init.body as URLSearchParams;
  const claims = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(form.get("client_secret")!.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")), c => c.charCodeAt(0))));
  assert.equal(claims.sub, config.clientId);
  assert.equal(claims.exp - claims.iat, 300);
});
test("legacy Apple accounts require reauthorization before any deletion", async () => {
  const config = await configuration(); const { handler, calls } = fixture(config);
  const response = await handler(input());
  assert.equal(response.status, 409);
  assert.equal((await response.json()).error, "apple_reauthentication_required");
  assert.equal(calls.some(call => call.url.endsWith("/rpc/delete_my_account")), false);
});
async function stored(config: Config) {
  return [{ apple_sub: subject, token_version: "token-version-a",
    encrypted_token: await seal("private-refresh-token", `${userId}:${subject}`, config) }];
}
test("provider failure preserves the account and never marks revocation", async () => {
  const config = await configuration(); const { handler, calls } = fixture(config, { rows: await stored(config), revokeStatus: 500 });
  assert.equal((await handler(input())).status, 502);
  assert.equal(calls.some(call => call.init.method === "PATCH" || call.url.endsWith("/rpc/delete_my_account")), false);
});
test("successful deletion revokes first, marks the same token version, then uses the user's transactional RPC", async () => {
  const config = await configuration(); const { handler, calls } = fixture(config, { rows: await stored(config) });
  assert.deepEqual(await (await handler(input("delete", { user_id: "victim" }))).json(), { deleted: true });
  assert.ok(calls[2].url.endsWith("/auth/revoke"));
  assert.equal((calls[2].init.body as URLSearchParams).get("token"), "private-refresh-token");
  assert.ok(calls[3].url.includes("token_version=eq.token-version-a"));
  assert.equal((calls[4].init.headers as Record<string, string>).Authorization, "Bearer user-session");
  assert.equal(calls[4].init.body, "{}");
});
test("concurrent token replacement prevents deletion of an unrevoked authorization", async () => {
  const config = await configuration(); const { handler, calls } = fixture(config, { rows: await stored(config), markRows: [] });
  assert.equal((await handler(input())).status, 503);
  assert.equal(calls.some(call => call.url.endsWith("/rpc/delete_my_account")), false);
});
test("non-Apple account deletion needs no Apple credentials and cannot call Apple's endpoints", async () => {
  const config = await configuration(); config.privateKey = "";
  const { handler, calls } = fixture(config, { apple: false });
  assert.equal((await handler(input())).status, 200);
  assert.equal(calls.length, 3);
  assert.ok(calls[2].url.endsWith("/rpc/delete_my_account"));
});
test("unlinking an Apple identity does not skip revocation of its retained token", async () => {
  const config = await configuration(); const { handler, calls } = fixture(config, { apple: false, rows: await stored(config) });
  assert.equal((await handler(input())).status, 200);
  assert.ok(calls.some(call => call.url.endsWith("/auth/revoke")));
});
test("database deletion failure is visible and retry revokes the same token again safely", async () => {
  const config = await configuration(); const rows = await stored(config);
  const first = fixture(config, { rows, deleteStatus: 500 });
  assert.equal((await first.handler(input())).status, 503);
  const retry = fixture(config, { rows });
  assert.equal((await retry.handler(input())).status, 200);
});
