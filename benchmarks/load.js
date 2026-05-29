import http from "k6/http";
import { check, sleep } from "k6";

const baseUrl = __ENV.BASE_URL || "http://localhost:4000";
const apiKey = __ENV.BOOTSTRAP_API_KEY || "";

export const options = {
  scenarios: {
    report_submission: {
      executor: "constant-vus",
      vus: 10,
      duration: "1m",
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<150"],
  },
};

export default function () {
  const headers = {
    "Content-Type": "application/json",
    "x-api-key": apiKey,
  };

  const response = http.post(
    `${baseUrl}/api/v1/reports`,
    JSON.stringify({
      report: {
        template_name: "ledger_summary",
        format: "json",
        requested_by: `load-${__VU}@example.com`,
        idempotency_key: `load-${__VU}-${__ITER}`,
        filters: { row_limit: 10 },
      },
    }),
    { headers }
  );

  check(response, { "submission accepted": (res) => res.status === 202 || res.status === 200 });
  sleep(0.5);
}
