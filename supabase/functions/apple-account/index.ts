import { createHandler } from "./handler.ts";

const value = (name: string) => Deno.env.get(name) ?? "";
Deno.serve(createHandler({
  authUrl: "http://auth:9999", restUrl: "http://rest:3000",
  serviceKey: value("SUPABASE_SERVICE_ROLE_KEY"),
  teamId: value("APPLE_SIGNIN_TEAM_ID"), clientId: "com.auraquest.auraQuest",
  keyId: value("APPLE_SIGNIN_KEY_ID"),
  privateKey: value("APPLE_SIGNIN_PRIVATE_KEY_B64") ? atob(value("APPLE_SIGNIN_PRIVATE_KEY_B64")) : "",
  encryptionKey: value("APPLE_TOKEN_ENCRYPTION_KEY"),
}));
