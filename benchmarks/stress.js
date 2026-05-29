import http from "k6/http";
import { check } from "k6";

const baseUrl = __ENV.BASE_URL || "http://localhost:4000";
const apiKey = __ENV.BOOTSTRAP_API_KEY || "";
const expectedStatuses = http.expectedStatuses(200, 202, 429);

export const options = {
  stages: [
    { duration: "30s", target: 10 },
    { duration: "30s", target: 30 },
    { duration: "30s", target: 60 },
    { duration: "30s", target: 0 },
  ],
};

export default function () {
  const response = http.post(
    `${baseUrl}/api/v1/reports`,
    JSON.stringify({
      report: {
        template_name: "invoice_audit",
        format: "zip",
        requested_by: `stress-${__VU}@example.com`,
        idempotency_key: `stress-${__VU}-${__ITER}`,
        filters: { row_limit: 20 },
      },
    }),
    {
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
      },
      responseCallback: expectedStatuses,
    }
  );

  check(response, {
    "accepted or rate limited": (res) => [202, 200, 429].includes(res.status),
  });
}
