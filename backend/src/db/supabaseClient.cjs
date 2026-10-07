const { createClient } = require('@supabase/supabase-js');

let supabaseClient;

function getSupabaseClient() {
  if (supabaseClient) return supabaseClient;

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error('Supabase Storage is not configured on the backend.');
  }

  supabaseClient = createClient(supabaseUrl, serviceRoleKey);
  return supabaseClient;
}

module.exports = { getSupabaseClient };
