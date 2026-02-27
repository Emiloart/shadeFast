import type { SupabaseClient } from '@supabase/supabase-js';

export async function hasAnyPremiumEntitlement(
  adminClient: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const { data, error } = await adminClient.rpc('has_any_premium_entitlement', {
    target_user: userId,
  });

  if (error) {
    throw new Error(`entitlement_check_failed:${error.message}`);
  }

  if (typeof data === 'boolean') {
    return data;
  }

  if (typeof data === 'string') {
    return data.toLowerCase() === 'true';
  }

  throw new Error('entitlement_check_invalid_response');
}
