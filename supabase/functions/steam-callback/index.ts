// Supabase Edge Function - Steam OAuth Callback Handler
// Redirects Steam OpenID callback to the mobile app

Deno.serve(async (req) => {
  const url = new URL(req.url);

  // Get all query parameters from Steam
  const params = url.searchParams;

  // Build deep link URL with all parameters
  const deepLinkUrl = `gamelib://steam-callback?${params.toString()}`;

  // Log for debugging
  console.log('Steam callback received:', {
    claimed_id: params.get('openid.claimed_id'),
    identity: params.get('openid.identity'),
    deepLink: deepLinkUrl,
  });

  // Direct 302 redirect to deep link
  return new Response(null, {
    status: 302,
    headers: {
      'Location': deepLinkUrl,
    },
  });
});
