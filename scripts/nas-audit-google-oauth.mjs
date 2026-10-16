// OAuth route inspection; starts a throwaway authorization, never completes it.
// No credentials, OAuth state, authorization codes or tokens are printed.
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';

function remote(command, input = '') {
  const r = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
    '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas',
    'denzel@192.168.178.123', command], { input, encoding: 'utf8', maxBuffer: 2_000_000 });
  if (r.status !== 0) throw Error('Read-only NAS OAuth check failed: ' + (r.error?.code ?? r.status));
  return r.stdout;
}

console.log(remote('/usr/bin/docker exec -i auraquest-auth sh -c \'env | while IFS= read -r line; do case "$line" in GOTRUE_SITE_URL=*|API_EXTERNAL_URL=*|GOTRUE_EXTERNAL_GOOGLE_ENABLED=*|GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI=*|GOTRUE_URI_ALLOW_LIST=*|GOTRUE_EXTERNAL_APPLE_ENABLED=*) printf "%s\\n" "$line";; esac; done\'').trim());

if (process.argv.includes('--logs')) {
  const summarize = value => {
    const text = String(value ?? '');
    if (text.includes('OAuth state not found or expired')) return 'OAuth state not found or expired';
    if (text.includes('OAuth state parameter missing')) return 'OAuth state parameter missing';
    if (text === 'request completed' || text === 'Redirecting to external provider') return text;
    return text ? '<other auth event; details suppressed>' : '';
  };
  const logs = remote('/usr/bin/docker logs --since 90m --tail 500 auraquest-auth 2>&1');
  const events = logs.split('\n').flatMap(line => {
    try {
      const entry = JSON.parse(line);
      if (!/callback|authorize/.test(entry.path ?? '') && !/oauth|google/i.test(entry.error ?? entry.msg ?? '')) return [];
      return [{ time: entry.time, level: entry.level, path: entry.path, status: entry.status,
        message: summarize(entry.msg), error: summarize(entry.error), errorCode: entry.error_code }];
    } catch { return []; }
  });
  console.log(JSON.stringify({ authEvents: events.slice(-30) }));
  const gateway = remote('/usr/bin/docker logs --since 90m --tail 1000 auraquest-gateway 2>&1');
  const match = gateway.split('\n').find(line => line.includes('d8a9770c24441003890b1a44ed66fb53'));
  console.log(JSON.stringify({ screenshotRequestFoundInGatewayLog: Boolean(match),
    ...(match ? { methodAndPath: match.match(/"(?:GET|POST) [^ ]+ HTTP[^\"]*"/)?.[0]?.replace(/\?[^ ]+/, '?<redacted>') } : {}) }));
}

for (const path of ['/auth/v1/health', '/auth/v1/settings', '/callback', '/auth/v1/callback']) {
  const response = await fetch('https://api.brenzel.uk' + path, { redirect: 'manual', signal: AbortSignal.timeout(15000) });
  const body = await response.text();
  console.log(JSON.stringify({ path, status: response.status,
    gatewayRouteMissing: body.includes('no Route matched'),
    ...(path.endsWith('/settings') && response.ok ? { googleEnabled: JSON.parse(body).external?.google } : {}) }));
}
const authorize = new URL('https://api.brenzel.uk/auth/v1/authorize');
authorize.searchParams.set('provider', 'google');
authorize.searchParams.set('redirect_to', 'io.supabase.auraquest://login-callback/');
const response = await fetch(authorize, { redirect: 'manual', signal: AbortSignal.timeout(15000) });
const location = response.headers.get('location');
if (!location) {
  console.log(JSON.stringify({ authorizeStatus: response.status, providerRedirectPresent: false }));
} else {
  const provider = new URL(location);
  console.log(JSON.stringify({ authorizeStatus: response.status, providerOrigin: provider.origin,
    callback: provider.searchParams.get('redirect_uri'), appRedirectRequested: 'io.supabase.auraquest://login-callback/' }));
}
