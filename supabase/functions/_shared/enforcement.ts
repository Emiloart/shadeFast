import type { SupabaseClient } from '@supabase/supabase-js';

export async function isUserBanned(
  adminClient: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const { data, error } = await adminClient.rpc('is_user_banned', {
    target_user: userId,
  });

  if (error) {
    throw new Error(`enforcement_check_failed:${error.message}`);
  }

  if (typeof data === 'boolean') {
    return data;
  }
  if (typeof data === 'string') {
    return data.toLowerCase() == 'true';
  }

  throw new Error('enforcement_check_invalid_response');
}
