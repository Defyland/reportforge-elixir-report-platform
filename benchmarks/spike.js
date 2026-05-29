import http from "k6/http";
import { check, sleep } from "k6";

const baseUrl = __ENV.BASE_URL || "http://localhost:4000";
const apiKey = __ENV.BOOTSTRAP_API_KEY || "";
const expectedStatuses = http.expectedStatuses(200, 202, 429);

export const options = {
  stages: [
    { duration: "10s", target: 5 },
    { duration: "10s", target: 80 },
    { duration: "20s", target: 80 },
    { duration: "10s", target: 5 },
  ],
};

export default function () {
  const response = http.post(
    `${baseUrl}/api/v1/reports`,
    JSON.stringify({
      report: {
        template_name: "cash_position",
        format: "csv",
        requested_by: `spike-${__VU}@example.com`,
        idempotency_key: `spike-${__VU}-${__ITER}`,
        filters: { row_limit: 5 },
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
    "spike request handled": (res) => [202, 200, 429].includes(res.status),
  });

  sleep(0.2);
}
