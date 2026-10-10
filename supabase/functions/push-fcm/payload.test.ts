import assert from "node:assert/strict";
import test from "node:test";
import { buildFcmMessage } from "./payload.ts";

test("Android retains its data-only high-priority delivery", () => {
  const message = buildFcmMessage({ token: "test", platform: "android", category: "invite", id: 42 });
  assert.deepEqual(message.data, { category: "invite", refId: "", id: "42" });
  assert.equal(message.android.priority, "high");
  assert.equal("notification" in message, false);
  assert.equal("alert" in message.apns.payload.aps, false);
});

test("iOS uses an APNs alert without exposing private notification text", () => {
  const message = buildFcmMessage({ token: "test", platform: "ios", category: "invite", refId: "quest-id", id: 42,
    // Extra caller fields must never reach the wire.
    ...{ title: "Private quest name", body: "Private user report" } });
  assert.equal(message.apns.headers["apns-push-type"], "alert");
  assert.equal(message.apns.headers["apns-priority"], "10");
  assert.equal(message.apns.payload.aps.sound, "default");
  assert.equal("content-available" in message.apns.payload.aps, false);
  assert.equal(JSON.stringify(message).includes("Private"), false);
  assert.equal(message.data.id, "42");
});
