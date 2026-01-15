import crypto from "node:crypto";

export function randomId(bytes = 32) {
  return crypto.randomBytes(bytes).toString("hex");
}

export function sha256Base64Url(input) {
  const digest = crypto.createHash("sha256").update(input).digest();
  return digest
    .toString("base64")
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

