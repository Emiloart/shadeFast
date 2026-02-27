import type { SupabaseClient } from '@supabase/supabase-js';

export type RateLimitResult = {
  allowed: boolean;
  currentCount: number;
};

export async function checkAndBumpRateLimit(
  adminClient: SupabaseClient,
  userId: string,
  action: string,
  windowSeconds: number,
  maxRequests: number,
): Promise<RateLimitResult> {
  const { data, error } = await adminClient.rpc('bump_rate_limit', {
    target_user: userId,
    target_action: action,
    window_seconds: windowSeconds,
  });

  if (error) {
    throw new Error(`rate_limit_rpc_failed:${error.message}`);
  }

  const parsed =
    typeof data === 'number'
      ? data
      : typeof data === 'string'
        ? Number(data)
        : NaN;

  if (!Number.isFinite(parsed)) {
    throw new Error('rate_limit_invalid_response');
  }

  return {
    allowed: parsed <= maxRequests,
    currentCount: parsed,
  };
}
