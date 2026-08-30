import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.0';
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from './supabase-config.js';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);

export async function requireRole(role, redirectPage) {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.user) {
    window.location.href = redirectPage;
    return null;
  }
  const { data: profile, error } = await supabase
    .from('profiles')
    .select('id, full_name, role, goal, level')
    .eq('id', session.user.id)
    .single();
  if (error || !profile || profile.role !== role) {
    await supabase.auth.signOut();
    window.location.href = role === 'coach' ? 'coach.html' : 'clienti.html';
    return null;
  }
  return { session, profile };
}
