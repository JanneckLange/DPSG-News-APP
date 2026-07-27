import dotenv from 'dotenv';
dotenv.config();

jest.mock('../src/fcm', () => ({
  sendEventNotification: jest.fn().mockResolvedValue('mocked'),
}));

import request from 'supertest';
import app from '../src/app';
import { clearAuthorData, clearEvents, close, connect, createAuthorForTesting } from '../src/db';

beforeAll(async () => {
  process.env.TEST_DATABASE_URL = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  process.env.AUTHOR_BOOTSTRAP_USERNAME = process.env.AUTHOR_BOOTSTRAP_USERNAME || 'bootstrap-admin';
  process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD = process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD || 'bootstrap-one-time-password';
  await connect();
});

beforeEach(async () => {
  await clearEvents();
  await clearAuthorData();
});

afterAll(async () => {
  await close();
});

describe('POST /api/auth/login', () => {
  it('logs in with valid credentials and returns tokens plus session metadata', async () => {
    await createAuthorForTesting({ username: 'auth-login-ok', password: 'correct-horse' });

    const response = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-login-ok', password: 'correct-horse' });

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      token: expect.any(String),
      accessToken: response.body.token,
      refreshToken: expect.any(String),
      author: { username: 'auth-login-ok' },
      requiresPasswordChange: false,
    });
    expect(response.body.expiresAt).toEqual(expect.any(String));
    expect(response.body.refreshExpiresAt).toEqual(expect.any(String));
  });

  it('rejects an incorrect password without revealing whether the username exists', async () => {
    await createAuthorForTesting({ username: 'auth-login-wrong-pw', password: 'correct-horse' });

    const response = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-login-wrong-pw', password: 'wrong-password' });

    expect(response.status).toBe(401);
    expect(response.body).toEqual({ error: 'Invalid credentials' });
  });

  it('rejects an unknown username with the same error as a wrong password', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({ username: 'does-not-exist', password: 'anything' });

    expect(response.status).toBe(401);
    expect(response.body).toEqual({ error: 'Invalid credentials' });
  });

  it('rejects a request missing username or password', async () => {
    const missingPassword = await request(app).post('/api/auth/login').send({ username: 'auth-login-ok' });
    expect(missingPassword.status).toBe(400);

    const missingUsername = await request(app).post('/api/auth/login').send({ password: 'correct-horse' });
    expect(missingUsername.status).toBe(400);
  });

  it('logs in via a one-time password and reports that a password change is required', async () => {
    await createAuthorForTesting({
      username: 'auth-login-otp',
      password: 'irrelevant-real-password',
      oneTimePassword: 'temp-pass-123',
    });

    const response = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-login-otp', password: 'temp-pass-123' });

    expect(response.status).toBe(200);
    expect(response.body.requiresPasswordChange).toBe(true);
  });
});

describe('POST /api/auth/refresh', () => {
  it('exchanges a valid refresh token for a new session', async () => {
    await createAuthorForTesting({ username: 'auth-refresh-ok', password: 'correct-horse' });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-refresh-ok', password: 'correct-horse' });

    const response = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: login.body.refreshToken });

    expect(response.status).toBe(200);
    expect(response.body.token).toEqual(expect.any(String));
    expect(response.body.author.username).toBe('auth-refresh-ok');
  });

  it('rejects an invalid or unknown refresh token', async () => {
    const response = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: 'not-a-real-refresh-token' });

    expect(response.status).toBe(401);
    expect(response.body).toEqual({ error: 'Invalid refresh token' });
  });

  it('rejects a request missing the refresh token', async () => {
    const response = await request(app).post('/api/auth/refresh').send({});
    expect(response.status).toBe(400);
  });
});

describe('POST /api/auth/logout', () => {
  it('requires authentication', async () => {
    const response = await request(app).post('/api/auth/logout');
    expect(response.status).toBe(401);
  });

  it('invalidates the session so it can no longer be used', async () => {
    await createAuthorForTesting({ username: 'auth-logout-ok', password: 'correct-horse' });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-logout-ok', password: 'correct-horse' });
    const token = login.body.token as string;

    const logoutResponse = await request(app)
      .post('/api/auth/logout')
      .set('authorization', `Bearer ${token}`);
    expect(logoutResponse.status).toBe(204);

    const meAfterLogout = await request(app)
      .get('/api/auth/me')
      .set('authorization', `Bearer ${token}`);
    expect(meAfterLogout.status).toBe(401);
  });
});

describe('GET /api/auth/me', () => {
  it('requires authentication', async () => {
    const response = await request(app).get('/api/auth/me');
    expect(response.status).toBe(401);
  });

  it('returns the current author session for a valid token', async () => {
    await createAuthorForTesting({ username: 'auth-me-ok', password: 'correct-horse' });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-me-ok', password: 'correct-horse' });

    const response = await request(app)
      .get('/api/auth/me')
      .set('authorization', `Bearer ${login.body.token}`);

    expect(response.status).toBe(200);
    expect(response.body.author.username).toBe('auth-me-ok');
    expect(response.body.requiresPasswordChange).toBe(false);
  });
});

describe('POST /api/auth/change-password', () => {
  it('requires authentication', async () => {
    const response = await request(app)
      .post('/api/auth/change-password')
      .send({ oldPassword: 'a', newPassword: 'new-password-1' });
    expect(response.status).toBe(401);
  });

  it('rejects a new password shorter than 8 characters', async () => {
    await createAuthorForTesting({ username: 'auth-pw-short', password: 'correct-horse' });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-pw-short', password: 'correct-horse' });

    const response = await request(app)
      .post('/api/auth/change-password')
      .set('authorization', `Bearer ${login.body.token}`)
      .send({ oldPassword: 'correct-horse', newPassword: 'short' });

    expect(response.status).toBe(400);
  });

  it('rejects an incorrect old password', async () => {
    await createAuthorForTesting({ username: 'auth-pw-wrong-old', password: 'correct-horse' });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-pw-wrong-old', password: 'correct-horse' });

    const response = await request(app)
      .post('/api/auth/change-password')
      .set('authorization', `Bearer ${login.body.token}`)
      .send({ oldPassword: 'totally-wrong', newPassword: 'new-password-1' });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({ error: 'Invalid old password' });
  });

  it('changes the password and allows logging in with the new one afterwards', async () => {
    await createAuthorForTesting({ username: 'auth-pw-ok', password: 'correct-horse' });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-pw-ok', password: 'correct-horse' });

    const changeResponse = await request(app)
      .post('/api/auth/change-password')
      .set('authorization', `Bearer ${login.body.token}`)
      .send({ oldPassword: 'correct-horse', newPassword: 'new-password-1' });
    expect(changeResponse.status).toBe(204);

    const oldPasswordLogin = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-pw-ok', password: 'correct-horse' });
    expect(oldPasswordLogin.status).toBe(401);

    const newPasswordLogin = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-pw-ok', password: 'new-password-1' });
    expect(newPasswordLogin.status).toBe(200);
  });

  it('does not require an old password when the author still must change a one-time password', async () => {
    await createAuthorForTesting({
      username: 'auth-pw-otp',
      password: 'irrelevant-real-password',
      oneTimePassword: 'temp-pass-123',
    });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ username: 'auth-pw-otp', password: 'temp-pass-123' });
    expect(login.body.requiresPasswordChange).toBe(true);

    const changeResponse = await request(app)
      .post('/api/auth/change-password')
      .set('authorization', `Bearer ${login.body.token}`)
      .send({ newPassword: 'new-password-1' });

    expect(changeResponse.status).toBe(204);
  });
});
