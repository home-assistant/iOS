#!/usr/bin/env bash
# Generates the certificates the mTLS E2E flow needs, all valid for one day:
#
#   ca.pem / ca.key         test CA, issuer of the two certificates below; added to the
#                           simulator's trusted root store by the `e2e` lane
#   server.pem / server.key served by the nginx proxy, SAN from $2
#   client.pem / client.key the client certificate the app must present
#   client.p12              the same client certificate, imported by the app during onboarding
#
# Nothing here is committed: the workflow regenerates everything on each run.
#
# Usage: generate-certs.sh <out-dir> [<san-list>]
#   san-list defaults to DNS:localhost,IP:127.0.0.1, which is where the simulator reaches the
#   proxy, since it shares the host's network stack.
#
# Environment:
#   E2E_MTLS_P12_PASSWORD  password of client.p12 (default e2ep12pass)
#   E2E_MTLS_CERT_ALIAS    friendly name of the p12 entry, which the app shows as the
#                          certificate's name (default e2eclient)
set -euo pipefail

OUT_DIR="${1:?usage: generate-certs.sh <out-dir> [<san-list>]}"
SAN_LIST="${2:-DNS:localhost,IP:127.0.0.1}"
P12_PASSWORD="${E2E_MTLS_P12_PASSWORD:-e2ep12pass}"
CERT_ALIAS="${E2E_MTLS_CERT_ALIAS:-e2eclient}"
VALIDITY_DAYS=1

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

openssl req -x509 -newkey rsa:2048 -nodes -days "$VALIDITY_DAYS" \
  -subj "/CN=HA iOS E2E CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -keyout ca.key -out ca.pem

openssl req -newkey rsa:2048 -nodes \
  -subj "/CN=localhost" \
  -addext "subjectAltName=$SAN_LIST" \
  -keyout server.key -out server.csr
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -days "$VALIDITY_DAYS" -copy_extensions copy -out server.pem

openssl req -newkey rsa:2048 -nodes \
  -subj "/CN=$CERT_ALIAS" \
  -addext "extendedKeyUsage=clientAuth" \
  -keyout client.key -out client.csr
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -days "$VALIDITY_DAYS" -copy_extensions copy -out client.pem

# SHA1/3DES rather than the PBES2/AES default, the same as home-assistant/android: every
# `SecPKCS12Import` on the supported iOS versions reads it, and so does LibreSSL's `openssl`.
openssl pkcs12 -export \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
  -inkey client.key -in client.pem -name "$CERT_ALIAS" \
  -passout "pass:$P12_PASSWORD" -out client.p12

rm -f server.csr client.csr ca.srl

echo "mTLS E2E certificates written to $OUT_DIR (valid $VALIDITY_DAYS day, SAN $SAN_LIST)"
