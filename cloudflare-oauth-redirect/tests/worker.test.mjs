import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Buffer } from 'node:buffer';

import { redirectToApp } from '../src/worker.js';

test('redirectToApp masks session cookie in HTML output', async () => {
  const cookie = 'zipline_session_value';
  const response = redirectToApp(true, cookie, null);
  const html = await response.text();

  assert.ok(!html.includes(cookie), 'HTML should not contain raw session cookie');

  const encodedCookie = Buffer.from(cookie, 'utf8').toString('base64');
  assert.ok(
    html.includes(encodedCookie),
    'HTML should include base64 encoded session payload',
  );

  assert.ok(
    html.includes('zipline://oauth-callback'),
    'HTML should still embed the deep link callback',
  );
});
