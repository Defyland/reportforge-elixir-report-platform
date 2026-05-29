import http from "k6/http";
import { check, sleep } from "k6";

const baseUrl = __ENV.BASE_URL || "http://localhost:4000";
const apiKey = __ENV.BOOTSTRAP_API_KEY || "";

export const options = {
  vus: 1,
  iterations: 5,
};

export default function () {
  const headers = {
    "Content-Type": "application/json",
    "x-api-key": apiKey,
  };

  const health = http.get(`${baseUrl}/healthz`);
  check(health, { "health ok": (response) => response.status === 200 });

  const createReport = http.post(
    `${baseUrl}/api/v1/reports`,
    JSON.stringify({
      report: {
        template_name: "cash_position",
        format: "csv",
        requested_by: "smoke@example.com",
        idempotency_key: `smoke-${__ITER}`,
        filters: { row_limit: 3 },
      },
    }),
    { headers }
  );

  check(createReport, {
    "report accepted": (response) => response.status === 202 || response.status === 200,
  });

  sleep(1);
}
