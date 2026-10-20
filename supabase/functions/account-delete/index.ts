import { createClient } from "npm:@supabase/supabase-js@2";
import { createAccountDeleteHandler } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL");
const publicKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY");
const secretKey = Deno.env.get("SUPABASE_SECRET_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

Deno.serve(createAccountDeleteHandler({
  configured: !!url && !!publicKey && !!secretKey,
  async authenticatedUser(bearer) {
    const client = createClient(url!, publicKey!, {
      global: { headers: { Authorization: bearer } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: { user }, error } = await client.auth.getUser();
    return error ? null : user;
  },
  async deleteUser(id) {
    const admin = createClient(url!, secretKey!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    // BioPulse tables reference auth.users(id) ON DELETE CASCADE.
    const { error } = await admin.auth.admin.deleteUser(id, false);
    return !error;
  },
}));
