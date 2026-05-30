// k6 load test for the ERP API.
//
// Install k6: https://k6.io/docs/get-started/installation/
// Run:
//   k6 run -e BASE_URL=http://localhost:8000/api/v1 \
//          -e EMAIL=admin@erp.local -e PASSWORD=Admin@1234 \
//          tests/load/api_load_test.js
//
// Stages ramp to 50 virtual users; thresholds fail the run if the API
// degrades (p95 latency > 500ms or error rate > 1%).

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000/api/v1';
const EMAIL    = __ENV.EMAIL    || 'admin@erp.local';
const PASSWORD = __ENV.PASSWORD || 'Admin@1234';

export const options = {
  stages: [
    { duration: '30s', target: 10 },  // warm up
    { duration: '1m',  target: 50 },  // ramp to 50 users
    { duration: '2m',  target: 50 },  // sustained load
    { duration: '30s', target: 0 },   // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
    errors: ['rate<0.01'],            // <1% application errors
  },
};

// Authenticate once per VU iteration setup.
export function setup() {
  const res = http.post(`${BASE_URL}/auth/login`, JSON.stringify({
    email: EMAIL,
    password: PASSWORD,
  }), { headers: { 'Content-Type': 'application/json', Accept: 'application/json' } });

  check(res, { 'login succeeded': (r) => r.status === 200 });
  return { token: res.json('data.token') };
}

export default function (data) {
  const authHeaders = {
    headers: {
      Authorization: `Bearer ${data.token}`,
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
  };

  group('health', () => {
    const res = http.get(`${BASE_URL}/health`);
    check(res, { 'health 200': (r) => r.status === 200 }) || errorRate.add(1);
  });

  group('profile', () => {
    const res = http.get(`${BASE_URL}/auth/me`, authHeaders);
    check(res, { 'me 200': (r) => r.status === 200 }) || errorRate.add(1);
  });

  group('list products', () => {
    const res = http.get(`${BASE_URL}/inventory/products?per_page=20`, authHeaders);
    check(res, {
      'products 200': (r) => r.status === 200,
      'products has data': (r) => Array.isArray(r.json('data')),
    }) || errorRate.add(1);
  });

  group('notifications', () => {
    const res = http.get(`${BASE_URL}/notifications/unread-count`, authHeaders);
    check(res, { 'unread 200': (r) => r.status === 200 }) || errorRate.add(1);
  });

  sleep(1);
}
