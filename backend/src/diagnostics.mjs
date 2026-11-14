import { UpstreamRejection } from "./weather.mjs";

const stages = new Set(["database", "weather", "state", "oauth", "fcm"]);
const categories = new Set([
  "invalid_measurement", "invalid_code", "invalid_units", "stale_weather",
  "invalid_forecast", "incomplete_forecast", "response_too_large",
  "invalid_fcm_configuration", "invalid_oauth_response", "invalid_fcm_response",
]);

class MonitorFailure extends Error {
  constructor(stage, cause) {
    super("weather_monitor_failed", { cause });
    this.stage = stage;
  }
}

export async function atStage(stage, action) {
  try {
    return await action();
  } catch (error) {
    throw error instanceof MonitorFailure ? error : new MonitorFailure(stage, error);
  }
}

export function logMonitorFailure(city, failure) {
  const error = failure instanceof MonitorFailure ? failure.cause : failure;
  const details = {
    city,
    stage: stages.has(failure?.stage) ? failure.stage : "database",
    category: error instanceof UpstreamRejection ? "upstream_rejected"
      : categories.has(error?.message) ? error.message
      : error instanceof SyntaxError ? "invalid_json"
      : ["TimeoutError", "AbortError"].includes(error?.name) ? "request_timeout"
      : "unexpected_error",
  };
  if (error instanceof UpstreamRejection) details.status = error.status;
  console.error("weather_monitor_failed", details);
}
