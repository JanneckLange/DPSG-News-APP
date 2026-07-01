import { getBuildInfo } from '../src/buildInfo';

describe('Build info', () => {
  it('returns defaults when metadata is missing', () => {
    const info = getBuildInfo({});

    expect(info).toEqual({
      buildTimeUtc: 'unknown',
      gitShaShort: 'unknown',
      gitRef: 'local-dev',
    });
  });

  it('truncates git sha to 12 chars', () => {
    const info = getBuildInfo({
      BUILD_TIME_UTC: '2026-07-01T08:45:00Z',
      GIT_SHA: 'abcdef1234567890abcdef1234567890abcdef12',
      GIT_REF: 'main',
    });

    expect(info).toEqual({
      buildTimeUtc: '2026-07-01T08:45:00Z',
      gitShaShort: 'abcdef123456',
      gitRef: 'main',
    });
  });
});