// Scheduled authenticated job. Set CRON_SECRET in Supabase function secrets.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
serve(async (req) => {
  if (req.method !== 'POST' || !Deno.env.get('CRON_SECRET') ||
      req.headers.get('x-cron-secret') !== Deno.env.get('CRON_SECRET')) {
    return new Response('Unauthorized', { status: 401 });
  }
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) return new Response('Server not configured', { status: 500 });
  const supabase = createClient(url, key, { auth: { persistSession: false } });
  const { data, error } = await supabase.rpc('finalize_due_auctions');
  const { data: expired, error: expiryError } = error ? { data: null, error: null } : await supabase.rpc('expire_stale_direct_orders');
  const failure = error ?? expiryError;
  return new Response(JSON.stringify(failure ? { error: failure.message } : { finalized: data, expiredDirectOrders: expired }), {
    status: failure ? 500 : 200, headers: { 'content-type': 'application/json' }
  });
});
