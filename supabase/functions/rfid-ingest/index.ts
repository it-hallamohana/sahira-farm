import { createHandler } from './handler.ts';

// These credentials only exist in the Edge Function environment, never on ESP/browser.
// SUPABASE_SERVICE_ROLE_KEY is provisioned automatically on hosted Edge Functions.
Deno.serve(createHandler({
  url: Deno.env.get('SUPABASE_URL') ?? '',
  serviceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
}));
