// =================================================================
//  AURA QUEST - Zustellung an Firebase Cloud Messaging
//
//  Wird von deliver_notifications() in der Datenbank aufgerufen, einmal
//  pro Geraet. Die Datenbank kann das nicht selbst: FCM verlangt ein
//  OAuth2-Token, das mit dem privaten Schluessel des Dienstkontos
//  signiert sein muss - RS256-Signaturen in plpgsql waeren Unfug.
//
//  WAS HIER NICHT ANKOMMT: Namen, Quest-Titel, Sprueche. Die Datenbank
//  schickt nur Kategorie und eine ID. Genau das geht weiter an Google.
//  Den Text holt sich die App anschliessend vom eigenen Server.
//
//  DESHALB IST ES EINE DATENNACHRICHT (data-only) und keine
//  notification-Nachricht: Bei letzterer wuerde Android den Text selbst
//  anzeigen - es gaebe also einen Text, den Google gesehen haette.
//  So weckt die Nachricht nur die App, die den Rest selbst erledigt.
// =================================================================

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

let account: ServiceAccount | null = null;

// Zugriffstoken sind eine Stunde gueltig. Bei jedem Versand eines zu
// holen waere eine zusaetzliche Netzrunde pro Benachrichtigung, also
// wird es bis kurz vor Ablauf behalten.
let cachedToken: { value: string; expiresAt: number } | null = null;

/// Der Schluessel kommt als base64-kodierte Umgebungsvariable.
///
/// NICHT als Datei: Die Edge-Runtime sperrt Dateizugriffe im Sandkasten
/// ("Deno.readTextFileSync is blocklisted"). Und nicht als roher JSON-Text,
/// weil dessen Anfuehrungszeichen und die \n im privaten Schluessel beim
/// Weg durch .env und docker compose zuverlaessig etwas zerlegen. Base64
/// ist eine Zeile ohne Sonderzeichen und uebersteht beides unbeschadet.
function loadAccount(): ServiceAccount {
  if (account) return account;
  const encoded = Deno.env.get("FCM_SERVICE_ACCOUNT_B64");
  if (!encoded) {
    throw new Error("FCM_SERVICE_ACCOUNT_B64 is not set");
  }
  const bytes = Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0));
  account = JSON.parse(new TextDecoder().decode(bytes)) as ServiceAccount;
  return account;
}

/** Wandelt den PEM-Text des Schluessels in einen Krypto-Schluessel um. */
async function importKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    bytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function base64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Holt ein OAuth2-Zugriffstoken ueber den JWT-Bearer-Ablauf. */
async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // Eine Minute Sicherheitsabstand, damit ein Token nicht genau
  // waehrend der Anfrage ablaeuft.
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const sa = loadAccount();
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));

  const key = await importKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const jwt = `${header}.${claims}.${base64url(new Uint8Array(signature))}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!response.ok) {
    throw new Error(`OAuth failed: ${response.status} ${await response.text()}`);
  }

  const data = await response.json();
  cachedToken = {
    value: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  };
  return cachedToken.value;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Die Funktion ist ueber Kong oeffentlich erreichbar, also muss sie
  // selbst pruefen, wer sie aufruft. Ohne das koennte jeder beliebige
  // Weckrufe an fremde Geraete schicken.
  const expected = Deno.env.get("PUSH_SHARED_SECRET") ?? "";
  if (!expected || request.headers.get("x-push-secret") !== expected) {
    return new Response("Forbidden", { status: 403 });
  }

  let payload: {
    token?: string;
    platform?: string;
    category?: string;
    refId?: string | null;
    id?: number;
  };
  try {
    payload = await request.json();
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }
  if (!payload.token || !payload.category) {
    return new Response("Missing token or category", { status: 400 });
  }

  try {
    const sa = loadAccount();
    const accessToken = await getAccessToken();

    const message: Record<string, unknown> = {
      token: payload.token,
      // Nur Daten, kein 'notification'-Block - siehe Kopf der Datei.
      data: {
        category: payload.category,
        refId: payload.refId ?? "",
        id: String(payload.id ?? ""),
      },
      android: {
        // Ohne 'high' laesst Android die Nachricht im Doze-Modus
        // liegen, bis das Geraet ohnehin aufwacht - womit die
        // Benachrichtigung ihren Zweck verloren haette.
        priority: "high",
      },
      apns: {
        headers: { "apns-priority": "5", "apns-push-type": "background" },
        payload: { aps: { "content-available": 1 } },
      },
    };

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message }),
      },
    );

    const text = await response.text();
    if (!response.ok) {
      console.error(`FCM ${response.status}: ${text}`);
      // 404 und 410 bedeutet: Token tot. Die Datenbank raeumt solche
      // Geraete anhand des Statuscodes selbst weg.
      return new Response(text, { status: response.status });
    }
    return new Response(text, {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error(`push-fcm failed: ${error}`);
    return new Response(String(error), { status: 500 });
  }
});
