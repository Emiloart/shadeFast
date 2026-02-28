#!/usr/bin/env bash
set -euo pipefail

assetlinks_path="deploy/domain/.well-known/assetlinks.json"
aasa_path="deploy/domain/.well-known/apple-app-site-association"

if [[ ! -f "$assetlinks_path" ]]; then
  echo "Missing file: $assetlinks_path"
  exit 1
fi

if [[ ! -f "$aasa_path" ]]; then
  echo "Missing file: $aasa_path"
  exit 1
fi

node - "$assetlinks_path" "$aasa_path" <<'NODE'
const fs = require('node:fs');

const assetlinksPath = process.argv[2];
const aasaPath = process.argv[3];

function fail(message) {
  console.error(message);
  process.exit(1);
}

let assetlinks;
try {
  assetlinks = JSON.parse(fs.readFileSync(assetlinksPath, 'utf8'));
} catch (error) {
  fail(`Invalid JSON in ${assetlinksPath}: ${error}`);
}

if (!Array.isArray(assetlinks) || assetlinks.length === 0) {
  fail('assetlinks.json must be a non-empty array.');
}

const androidTarget = assetlinks
  .map((entry) => entry?.target)
  .find((target) => target?.namespace === 'android_app');

if (!androidTarget) {
  fail('assetlinks.json is missing android_app target.');
}

if (androidTarget.package_name !== 'io.shadefast.mobile') {
  fail(
    `assetlinks.json package_name must be io.shadefast.mobile (got: ${androidTarget.package_name ?? 'undefined'}).`,
  );
}

if (
  !Array.isArray(androidTarget.sha256_cert_fingerprints) ||
  androidTarget.sha256_cert_fingerprints.length === 0
) {
  fail('assetlinks.json must include at least one sha256_cert_fingerprints value.');
}

let aasa;
try {
  aasa = JSON.parse(fs.readFileSync(aasaPath, 'utf8'));
} catch (error) {
  fail(`Invalid JSON in ${aasaPath}: ${error}`);
}

const details = aasa?.applinks?.details;
if (!Array.isArray(details) || details.length === 0) {
  fail('apple-app-site-association must include applinks.details.');
}

const appIds = details.flatMap((entry) => {
  if (Array.isArray(entry?.appIDs)) {
    return entry.appIDs;
  }
  if (typeof entry?.appID === 'string' && entry.appID.length > 0) {
    return [entry.appID];
  }
  return [];
});

if (!appIds.some((id) => String(id).endsWith('.io.shadefast.mobile'))) {
  fail('apple-app-site-association must include an appID/appIDs entry ending with .io.shadefast.mobile');
}

const paths = details.flatMap((entry) => (Array.isArray(entry?.paths) ? entry.paths : []));
for (const requiredPath of ['/join/*', '/chat/*']) {
  if (!paths.includes(requiredPath)) {
    fail(`apple-app-site-association is missing path: ${requiredPath}`);
  }
}

console.log('Domain association files are valid.');
NODE
