import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ExpireContentPayload = {
  limit?: number;
  dryRun?: boolean;
};

const defaultLimit = 200;
const maxLimit = 500;

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'method_not_allowed', 'Use POST for this route.');
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    return errorResponse(500, 'misconfigured_env', 'Missing function secrets.');
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return errorResponse(401, 'invalid_auth', 'Service role authorization required.');
  }
  const accessToken = authHeader.replace('Bearer ', '').trim();
  if (!accessToken) {
    return errorResponse(401, 'invalid_auth', 'Service role authorization required.');
  }

  const serviceAuthClient = createClient(supabaseUrl, accessToken, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
  const { error: serviceAuthError } = await serviceAuthClient.auth.admin.listUsers({
    page: 1,
    perPage: 1,
  });
  if (serviceAuthError) {
    return errorResponse(401, 'invalid_auth', 'Service role authorization required.');
  }

  let payload: ExpireContentPayload;
  try {
    payload = (await req.json()) as ExpireContentPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const requestedLimit = payload.limit ?? defaultLimit;
  if (
    !Number.isInteger(requestedLimit) ||
    requestedLimit < 1 ||
    requestedLimit > maxLimit
  ) {
    return errorResponse(
      400,
      'invalid_limit',
      `limit must be between 1 and ${maxLimit}.`,
    );
  }

  const dryRun = payload.dryRun ?? false;
  if (typeof dryRun !== 'boolean') {
    return errorResponse(400, 'invalid_dry_run', 'dryRun must be boolean.');
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: queueRows, error: queueError } = await adminClient
    .from('expired_media_queue')
    .select('id, media_url')
    .is('processed_at', null)
    .order('enqueued_at', { ascending: true })
    .limit(requestedLimit);

  if (queueError) {
    console.error('expire-content queue lookup failed', queueError);
    return errorResponse(500, 'queue_lookup_failed', 'Failed to fetch media queue.');
  }

  const rows = queueRows ?? [];
  if (rows.length === 0) {
    return jsonResponse(
      {
        processed: 0,
        failed: 0,
        queued: 0,
      },
      200,
    );
  }

  const validRows: Array<{ id: string; path: string }> = [];
  const invalidIds: string[] = [];

  for (const row of rows) {
    const path = extractMediaPath(row.media_url);
    if (!path) {
      invalidIds.push(row.id);
      continue;
    }
    validRows.push({
      id: row.id,
      path,
    });
  }

  if (dryRun) {
    return jsonResponse(
      {
        processed: 0,
        failed: invalidIds.length,
        queued: rows.length,
        dryRun: true,
      },
      200,
    );
  }

  let processed = 0;
  let failed = 0;

  if (invalidIds.length > 0) {
    const { error: invalidUpdateError } = await adminClient
      .from('expired_media_queue')
      .update({
        processed_at: new Date().toISOString(),
        last_error: 'unrecognized_media_url',
      })
      .in('id', invalidIds);

    if (invalidUpdateError) {
      console.error('expire-content invalid row update failed', invalidUpdateError);
      failed += invalidIds.length;
    } else {
      processed += invalidIds.length;
    }
  }

  if (validRows.length > 0) {
    const paths = validRows.map((row) => row.path);
    const ids = validRows.map((row) => row.id);

    const { error: removeError } = await adminClient.storage.from('media').remove(paths);
    if (removeError) {
      console.error('expire-content storage remove failed', removeError);

      const { error: markError } = await adminClient
        .from('expired_media_queue')
        .update({
          last_error: removeError.message,
        })
        .in('id', ids);

      if (markError) {
        console.error('expire-content queue error update failed', markError);
      }

      failed += ids.length;
    } else {
      const { error: updateError } = await adminClient
        .from('expired_media_queue')
        .update({
          processed_at: new Date().toISOString(),
          last_error: null,
        })
        .in('id', ids);

      if (updateError) {
        console.error('expire-content queue completion update failed', updateError);
        failed += ids.length;
      } else {
        processed += ids.length;
      }
    }
  }

  return jsonResponse(
    {
      processed,
      failed,
      queued: rows.length,
    },
    200,
  );
});

function extractMediaPath(mediaUrl: string): string | null {
  try {
    const parsed = new URL(mediaUrl);
    const match = parsed.pathname.match(/\/storage\/v1\/object\/(?:public|sign)\/media\/(.+)$/);
    if (!match || !match[1]) {
      return null;
    }

    return decodeURIComponent(match[1]);
  } catch (_) {
    return null;
  }
}
