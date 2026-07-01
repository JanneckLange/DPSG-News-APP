import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from '@jest/globals';
import app from '../src/app';

describe('Health endpoint', () => {
  const originalBuildTime = process.env.BUILD_TIME_UTC;
  const originalGitSha = process.env.GIT_SHA;
  const originalGitRef = process.env.GIT_REF;

  beforeEach(() => {
    process.env.BUILD_TIME_UTC = '2026-07-01T12:00:00Z';
    process.env.GIT_SHA = '0123456789abcdef0123456789abcdef01234567';
    process.env.GIT_REF = 'main';
  });

  afterEach(() => {
    if (originalBuildTime === undefined) {
      delete process.env.BUILD_TIME_UTC;
    } else {
      process.env.BUILD_TIME_UTC = originalBuildTime;
    }

    if (originalGitSha === undefined) {
      delete process.env.GIT_SHA;
    } else {
      process.env.GIT_SHA = originalGitSha;
    }

    if (originalGitRef === undefined) {
      delete process.env.GIT_REF;
    } else {
      process.env.GIT_REF = originalGitRef;
    }
  });

  it('returns tree version and build metadata', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
    expect(response.body.treeVersion).toBe('2026-07-01T00:00:00Z');
    expect(response.body.build).toEqual({
      buildTimeUtc: '2026-07-01T12:00:00Z',
      gitShaShort: '0123456789ab',
      gitRef: 'main',
    });
  });

  it('returns the incoming x-request-id header unchanged', async () => {
    const response = await request(app)
      .get('/health')
      .set('x-request-id', 'client-provided-request-id');

    expect(response.status).toBe(200);
    expect(response.headers['x-request-id']).toBe('client-provided-request-id');
  });

  it('generates x-request-id when no header is provided', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.headers['x-request-id']).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
    );
  });
});