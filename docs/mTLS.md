# mTLS (Mutual TLS) Support

> ⚠️ **EXPERIMENTAL FEATURE**
> 
> This feature is experimental and may change or be removed in future versions.
> Use at your own risk and report any issues you encounter.

## What is mTLS?

Mutual TLS (mTLS) is a security protocol where both the client and server authenticate each other using certificates. Unlike standard TLS where only the server presents a certificate, mTLS requires the client to also present a valid certificate.

This is commonly used to:
- Secure Home Assistant access behind a reverse proxy (nginx, Traefik, etc.)
- Add an extra layer of authentication beyond username/password
- Restrict access to devices with trusted certificates only

## How It Works

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   iOS App    │  mTLS   │    Nginx     │  HTTP   │     Home     │
│              │◄───────►│   (Proxy)    │◄───────►│  Assistant   │
│ + Client Cert│         │ + Server Cert│         │              │
└──────────────┘         └──────────────┘         └──────────────┘
```

1. **Server Certificate**: The reverse proxy (e.g., nginx) presents its SSL certificate
2. **Client Certificate**: The iOS app presents its client certificate (.p12 file)
3. **Mutual Verification**: Both sides verify each other's certificates
4. **Secure Connection**: Once verified, traffic flows through encrypted tunnel

## Setup Requirements

### 1. Generate Certificates

You'll need:
- A Certificate Authority (CA) certificate
- A server certificate signed by the CA
- A client certificate signed by the CA (exported as .p12)

Example using OpenSSL:

```bash
# Create CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/CN=My Home CA"

# Create Server Certificate
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=homeassistant.local"
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt

# Create Client Certificate
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr -subj "/CN=ios-app"
openssl x509 -req -days 365 -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt

# Export client certificate as .p12 (for iOS)
openssl pkcs12 -export -out client.p12 -inkey client.key -in client.crt -certfile ca.crt -password pass:your_password
```

### 2. Configure Reverse Proxy (nginx example)

```nginx
server {
    listen 8443 ssl;
    server_name homeassistant.local;

    # Server certificate
    ssl_certificate /path/to/server.crt;
    ssl_certificate_key /path/to/server.key;

    # mTLS - require client certificate
    ssl_client_certificate /path/to/ca.crt;
    ssl_verify_client on;

    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://homeassistant:8123;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 3. Transfer Client Certificate to iOS

Transfer the `.p12` file to your iOS device via:
- AirDrop
- iCloud Drive
- Email attachment
- Any file sharing method

## Using mTLS in the App

### During Onboarding

1. Enter your Home Assistant URL (e.g., `https://homeassistant.local:8443`)
2. If the server requires mTLS, you'll see a prompt to import a client certificate
3. Tap "Import Certificate" and select your `.p12` file
4. Enter the password used when creating the .p12 file
5. Continue with normal login flow

### Certificate Storage

- Certificates are stored securely in the iOS Keychain
- The certificate reference is saved with your server configuration
- Certificates persist across app reinstalls (stored in Keychain)

## Troubleshooting

### "SSL Handshake Failed" or Connection Errors

- Verify your client certificate is signed by the same CA configured on the server
- Check that the .p12 file includes the full certificate chain
- Ensure the certificate hasn't expired

### "Certificate Required" but No Prompt

- Make sure you're using HTTPS, not HTTP
- Verify the server is actually requiring client certificates (`ssl_verify_client on`)

### WebSocket Connection Issues

- Check that your proxy configuration supports WebSocket upgrade
- Verify the proxy passes through the client certificate for WebSocket connections

### Webhook Errors

- Webhooks use a separate connection that also requires the client certificate
- If webhooks fail with 400/401 errors, verify the certificate is properly configured

## Technical Details

The app handles mTLS at three different layers:

1. **Alamofire (HTTP requests)**: Uses `ClientCertificateSessionDelegate` to provide client certificates for API calls

2. **HAKit/Starscream (WebSocket)**: Uses `FoundationTransport` with custom SSL stream configuration for the WebSocket connection to Home Assistant

3. **WebhookManager (Background uploads)**: Uses `ConnectionInfo.evaluate()` to handle client certificate challenges for webhook requests

## Limitations

- **watchOS**: mTLS is not supported on Apple Watch due to platform limitations
- **Local Push**: May not work with mTLS configurations
- **Siri/Shortcuts**: May have limited functionality with mTLS

## Security Considerations

- Keep your `.p12` file and password secure
- Use strong passwords when exporting certificates
- Rotate certificates periodically
- Revoke compromised certificates immediately by updating your CA

---

## Need Help?

If you encounter issues with mTLS:
1. Check the app logs (Settings → Debug → Export Logs)
2. Verify your certificate chain with: `openssl verify -CAfile ca.crt client.crt`
3. Test your nginx configuration: `nginx -t`

---

*This documentation is for the experimental mTLS feature in the Home Assistant iOS app.*
