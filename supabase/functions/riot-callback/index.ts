// Supabase Edge Function - Riot Games RSO OAuth Callback Handler
// Exchanges authorization code for tokens and redirects to the mobile app

const RIOT_TOKEN_URL = 'https://auth.riotgames.com/token';
const RIOT_ACCOUNT_URL = 'https://americas.api.riotgames.com/riot/account/v1/accounts/me';

// Get credentials from environment
const RIOT_CLIENT_ID = Deno.env.get('RIOT_CLIENT_ID') || '';
const RIOT_CLIENT_SECRET = Deno.env.get('RIOT_CLIENT_SECRET') || '';

interface RiotTokenResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
  scope: string;
}

interface RiotAccountResponse {
  puuid: string;
  gameName: string;
  tagLine: string;
}

async function exchangeCodeForTokens(code: string, redirectUri: string): Promise<RiotTokenResponse | null> {
  try {
    // Create Basic auth header
    const credentials = btoa(`${RIOT_CLIENT_ID}:${RIOT_CLIENT_SECRET}`);

    const response = await fetch(RIOT_TOKEN_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: redirectUri,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('Token exchange failed:', error);
      return null;
    }

    return await response.json() as RiotTokenResponse;
  } catch (error) {
    console.error('Token exchange error:', error);
    return null;
  }
}

async function getAccountInfo(accessToken: string): Promise<RiotAccountResponse | null> {
  try {
    const response = await fetch(RIOT_ACCOUNT_URL, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('Account info fetch failed:', error);
      return null;
    }

    return await response.json() as RiotAccountResponse;
  } catch (error) {
    console.error('Account info error:', error);
    return null;
  }
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const error = url.searchParams.get('error');
  const errorDescription = url.searchParams.get('error_description');

  // Check for OAuth errors
  if (error) {
    console.error('OAuth error:', error, errorDescription);
    const errorDeepLink = `gamelib://riot-callback?error=${encodeURIComponent(error)}&error_description=${encodeURIComponent(errorDescription || '')}`;
    return new Response(null, {
      status: 302,
      headers: { 'Location': errorDeepLink },
    });
  }

  // Check for authorization code
  if (!code) {
    console.error('No authorization code received');
    const errorDeepLink = 'gamelib://riot-callback?error=no_code&error_description=Authorization%20code%20not%20received';
    return new Response(null, {
      status: 302,
      headers: { 'Location': errorDeepLink },
    });
  }

  // Check credentials
  if (!RIOT_CLIENT_ID || !RIOT_CLIENT_SECRET) {
    console.error('Riot credentials not configured');
    const errorDeepLink = 'gamelib://riot-callback?error=config_error&error_description=Server%20configuration%20error';
    return new Response(null, {
      status: 302,
      headers: { 'Location': errorDeepLink },
    });
  }

  console.log('Riot callback received, exchanging code for tokens...');

  // Get the redirect URI (this function's URL)
  const redirectUri = `${url.origin}${url.pathname}`;

  // Exchange code for tokens
  const tokens = await exchangeCodeForTokens(code, redirectUri);
  if (!tokens) {
    const errorDeepLink = 'gamelib://riot-callback?error=token_error&error_description=Failed%20to%20exchange%20authorization%20code';
    return new Response(null, {
      status: 302,
      headers: { 'Location': errorDeepLink },
    });
  }

  console.log('Tokens received, fetching account info...');

  // Get account info
  const account = await getAccountInfo(tokens.access_token);
  if (!account) {
    const errorDeepLink = 'gamelib://riot-callback?error=account_error&error_description=Failed%20to%20fetch%20account%20info';
    return new Response(null, {
      status: 302,
      headers: { 'Location': errorDeepLink },
    });
  }

  console.log('Account info received:', {
    puuid: account.puuid.substring(0, 8) + '...',
    riotId: `${account.gameName}#${account.tagLine}`,
  });

  // Build success deep link
  const deepLink = new URL('gamelib://riot-callback');
  deepLink.searchParams.set('access_token', tokens.access_token);
  deepLink.searchParams.set('refresh_token', tokens.refresh_token);
  deepLink.searchParams.set('expires_in', tokens.expires_in.toString());
  deepLink.searchParams.set('puuid', account.puuid);
  deepLink.searchParams.set('game_name', account.gameName);
  deepLink.searchParams.set('tag_line', account.tagLine);

  console.log('Redirecting to app with account:', `${account.gameName}#${account.tagLine}`);

  return new Response(null, {
    status: 302,
    headers: { 'Location': deepLink.toString() },
  });
});
