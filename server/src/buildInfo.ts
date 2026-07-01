export type BuildInfo = {
  buildTimeUtc: string;
  gitShaShort: string;
  gitRef: string;
};

function normalizeValue(value: string | undefined, fallback: string): string {
  const normalized = value?.trim();
  return normalized ? normalized : fallback;
}

function shortSha(value: string | undefined): string {
  const sha = normalizeValue(value, 'unknown');
  if (sha === 'unknown') {
    return sha;
  }
  return sha.slice(0, 12);
}

export function getBuildInfo(env: NodeJS.ProcessEnv = process.env): BuildInfo {
  return {
    buildTimeUtc: normalizeValue(env.BUILD_TIME_UTC, 'unknown'),
    gitShaShort: shortSha(env.GIT_SHA),
    gitRef: normalizeValue(env.GIT_REF, 'local-dev'),
  };
}