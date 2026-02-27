const imagePathPrefix = 'posts/';
const videoPathPrefix = 'videos/';

export type MediaType = 'image' | 'video';

export function extractMediaPath(mediaUrl: string): string | null {
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

export function inferMediaTypeFromPath(objectPath: string): MediaType | null {
  if (objectPath.startsWith(imagePathPrefix)) {
    return 'image';
  }

  if (objectPath.startsWith(videoPathPrefix)) {
    return 'video';
  }

  return null;
}

export function isOwnedMediaPath(objectPath: string, userId: string): boolean {
  if (!userId || !objectPath) {
    return false;
  }

  return (
    objectPath.startsWith(`${imagePathPrefix}${userId}/`) ||
    objectPath.startsWith(`${videoPathPrefix}${userId}/`)
  );
}
