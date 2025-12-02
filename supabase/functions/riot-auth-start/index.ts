// Supabase Edge Function - Riot Games RSO OAuth Start
// Redirects user to Riot login with proper client_id

const RIOT_AUTH_URL = 'https://auth.riotgames.com/authorize';
const RIOT_CLIENT_ID = Deno.env.get('RIOT_CLIENT_ID') || '';

Deno.serve(async (req) => {
  const url = new URL(req.url);

  // Check credentials
  if (!RIOT_CLIENT_ID) {
    return new Response(JSON.stringify({
      error: 'Riot client_id not configured',
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Build callback URL (riot-callback function)
  const callbackUrl = url.origin.replace('riot-auth-start', 'riot-callback');

  // Build Riot authorization URL
  const riotAuthUrl = new URL(RIOT_AUTH_URL);
  riotAuthUrl.searchParams.set('client_id', RIOT_CLIENT_ID);
  riotAuthUrl.searchParams.set('redirect_uri', `${url.origin}/functions/v1/riot-callback`);
  riotAuthUrl.searchParams.set('response_type', 'code');
  riotAuthUrl.searchParams.set('scope', 'openid offline_access cpid');

  console.log('Redirecting to Riot auth:', riotAuthUrl.toString());

  return new Response(null, {
    status: 302,
    headers: { 'Location': riotAuthUrl.toString() },
  });
});
