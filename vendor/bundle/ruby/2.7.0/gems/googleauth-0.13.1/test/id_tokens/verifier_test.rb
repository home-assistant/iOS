# Copyright 2020 Google LLC
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#     * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require "helper"

describe Google::Auth::IDTokens::Verifier do
  describe "verify_oidc" do
    let(:oidc_token) {
      "eyJhbGciOiJSUzI1NiIsImtpZCI6IjQ5MjcxMGE3ZmNkYjE1Mzk2MGNlMDFmNzYwNTIwY" \
      "TMyYzg0NTVkZmYiLCJ0eXAiOiJKV1QifQ.eyJhdWQiOiJodHRwOi8vZXhhbXBsZS5jb20" \
      "iLCJhenAiOiI1NDIzMzkzNTc2MzgtY3IwZHNlcnIyZXZnN3N2MW1lZ2hxZXU3MDMyNzRm" \
      "M2hAZGV2ZWxvcGVyLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJlbWFpbCI6IjU0MjMzOTM1N" \
      "zYzOC1jcjBkc2VycjJldmc3c3YxbWVnaHFldTcwMzI3NGYzaEBkZXZlbG9wZXIuZ3Nlcn" \
      "ZpY2VhY2NvdW50LmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJleHAiOjE1OTEzNDI" \
      "3NzYsImlhdCI6MTU5MTMzOTE3NiwiaXNzIjoiaHR0cHM6Ly9hY2NvdW50cy5nb29nbGUu" \
      "Y29tIiwic3ViIjoiMTA0MzQxNDczMTMxODI1OTU3NjAzIn0.GGDE_5HoLacyqdufdxnAC" \
      "rXxYySKQYAzSQ5qfGjSUriuO3uLm2-rwSPFfLzzBeflEHdVX7XRFFszpxKajuZklF4dXd" \
      "0evB1u5i3QeCJ8MSZKKx6qus_ETJv4rtuPNEuyhaRcShB7BwI8RY0IZ4_EDrhYqYInrO2" \
      "wQyJGYvc41JcmoKzRoNnEVydN0Qppt9bqevq_lJg-9UjJkJ2QHjPfTgMjwhLIgNptKgtR" \
      "qdoRpJmleFlbuUqyPPJfAzv3Tc6h3kw88tEcI8R3n04xmHOSMwERFFQYJdQDMd2F9SSDe" \
      "rh40codO_GuPZ7bEUiKq9Lkx2LH5TuhythfsMzIwJpaEA"
    }
    let(:oidc_jwk_body) {
      <<~JWK
      {
        "keys": [
          {
            "kid": "fb8ca5b7d8d9a5c6c6788071e866c6c40f3fc1f9",
            "e": "AQAB",
            "alg": "RS256",
            "use": "sig",
            "n": "zK8PHf_6V3G5rU-viUOL1HvAYn7q--dxMoUkt7x1rSWX6fimla-lpoYAKhFTLUELkRKy_6UDzfybz0P9eItqS2UxVWYpKYmKTQ08HgUBUde4GtO_B0SkSk8iLtGh653UBBjgXmfzdfQEz_DsaWn7BMtuAhY9hpMtJye8LQlwaS8ibQrsC0j0GZM5KXRITHwfx06_T1qqC_MOZRA6iJs-J2HNlgeyFuoQVBTY6pRqGXa-qaVsSG3iU-vqNIciFquIq-xydwxLqZNksRRer5VAsSHf0eD3g2DX-cf6paSy1aM40svO9EfSvG_07MuHafEE44RFvSZZ4ubEN9U7ALSjdw",
            "kty": "RSA"
          },
          {
            "kty": "RSA",
            "kid": "492710a7fcdb153960ce01f760520a32c8455dff",
            "e": "AQAB",
            "alg": "RS256",
            "use": "sig",
            "n": "wl6TaY_3dsuLczYH_hioeQ5JjcLKLGYb--WImN9_IKMkOj49dgs25wkjsdI9XGJYhhPJLlvfjIfXH49ZGA_XKLx7fggNaBRZcj1y-I3_77tVa9N7An5JLq3HT9XVt0PNTq0mtX009z1Hva4IWZ5IhENx2rWlZOfFAXiMUqhnDc8VY3lG7vr8_VG3cw3XRKvlZQKbb6p2YIMFsUwaDGL2tVF4SkxpxIazUYfOY5lijyVugNTslOBhlEMq_43MZlkznSrbFx8ToQ2bQX4Shj-r9pLyofbo6A7K9mgWnQXGY5rQVLPYYRzUg0ThWDzwHdgxYC5MNxKyQH4RC2LPv3U0LQ"
          }
        ]
      }
      JWK
    }
    let(:expected_aud) { "http://example.com" }
    let(:expected_azp) { "542339357638-cr0dserr2evg7sv1meghqeu703274f3h@developer.gserviceaccount.com" }
    let(:unexpired_test_time) { Time.at 1591339181 }
    let(:expired_test_time) { unexpired_test_time + 86400 }

    after do
      WebMock.reset!
      Google::Auth::IDTokens.forget_sources!
    end

    it "verifies a good token with iss, aud, and azp checks" do
      stub_request(:get, Google::Auth::IDTokens::OAUTH2_V3_CERTS_URL).to_return(body: oidc_jwk_body)
      Time.stub :now, unexpired_test_time do
        Google::Auth::IDTokens.verify_oidc oidc_token, aud: expected_aud, azp: expected_azp
      end
    end

    it "fails to verify a bad token" do
      stub_request(:get, Google::Auth::IDTokens::OAUTH2_V3_CERTS_URL).to_return(body: oidc_jwk_body)
      Time.stub :now, unexpired_test_time do
        assert_raises Google::Auth::IDTokens::SignatureError do
          Google::Auth::IDTokens.verify_oidc "#{oidc_token}x"
        end
      end
    end

    it "fails to verify a token with the wrong aud" do
      stub_request(:get, Google::Auth::IDTokens::OAUTH2_V3_CERTS_URL).to_return(body: oidc_jwk_body)
      Time.stub :now, unexpired_test_time do
        assert_raises Google::Auth::IDTokens::AudienceMismatchError do
          Google::Auth::IDTokens.verify_oidc oidc_token, aud: ["hello", "world"]
        end
      end
    end

    it "fails to verify a token with the wrong azp" do
      stub_request(:get, Google::Auth::IDTokens::OAUTH2_V3_CERTS_URL).to_return(body: oidc_jwk_body)
      Time.stub :now, unexpired_test_time do
        assert_raises Google::Auth::IDTokens::AuthorizedPartyMismatchError do
          Google::Auth::IDTokens.verify_oidc oidc_token, azp: "hello"
        end
      end
    end

    it "fails to verify a token with the wrong issuer" do
      stub_request(:get, Google::Auth::IDTokens::OAUTH2_V3_CERTS_URL).to_return(body: oidc_jwk_body)
      Time.stub :now, unexpired_test_time do
        assert_raises Google::Auth::IDTokens::IssuerMismatchError do
          Google::Auth::IDTokens.verify_oidc oidc_token, iss: "hello"
        end
      end
    end

    it "fails to verify an expired token" do
      stub_request(:get, Google::Auth::IDTokens::OAUTH2_V3_CERTS_URL).to_return(body: oidc_jwk_body)
      Time.stub :now, expired_test_time do
        assert_raises Google::Auth::IDTokens::ExpiredTokenError do
          Google::Auth::IDTokens.verify_oidc oidc_token
        end
      end
    end
  end

  describe "verify_iap" do
    let(:iap_token) {
      "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjBvZUxjUSJ9.eyJhdWQiOiIvcH" \
      "JvamVjdHMvNjUyNTYyNzc2Nzk4L2FwcHMvY2xvdWQtc2FtcGxlcy10ZXN0cy1waHAtaWFwI" \
      "iwiZW1haWwiOiJkYXp1bWFAZ29vZ2xlLmNvbSIsImV4cCI6MTU5MTMzNTcyNCwiZ29vZ2xl" \
      "Ijp7ImFjY2Vzc19sZXZlbHMiOlsiYWNjZXNzUG9saWNpZXMvNTE4NTUxMjgwOTI0L2FjY2V" \
      "zc0xldmVscy9yZWNlbnRTZWN1cmVDb25uZWN0RGF0YSIsImFjY2Vzc1BvbGljaWVzLzUxOD" \
      "U1MTI4MDkyNC9hY2Nlc3NMZXZlbHMvdGVzdE5vT3AiLCJhY2Nlc3NQb2xpY2llcy81MTg1N" \
      "TEyODA5MjQvYWNjZXNzTGV2ZWxzL2V2YXBvcmF0aW9uUWFEYXRhRnVsbHlUcnVzdGVkIiwi" \
      "YWNjZXNzUG9saWNpZXMvNTE4NTUxMjgwOTI0L2FjY2Vzc0xldmVscy9jYWFfZGlzYWJsZWQ" \
      "iLCJhY2Nlc3NQb2xpY2llcy81MTg1NTEyODA5MjQvYWNjZXNzTGV2ZWxzL3JlY2VudE5vbk" \
      "1vYmlsZVNlY3VyZUNvbm5lY3REYXRhIiwiYWNjZXNzUG9saWNpZXMvNTE4NTUxMjgwOTI0L" \
      "2FjY2Vzc0xldmVscy9jb25jb3JkIiwiYWNjZXNzUG9saWNpZXMvNTE4NTUxMjgwOTI0L2Fj" \
      "Y2Vzc0xldmVscy9mdWxseVRydXN0ZWRfY2FuYXJ5RGF0YSIsImFjY2Vzc1BvbGljaWVzLzU" \
      "xODU1MTI4MDkyNC9hY2Nlc3NMZXZlbHMvZnVsbHlUcnVzdGVkX3Byb2REYXRhIl19LCJoZC" \
      "I6Imdvb2dsZS5jb20iLCJpYXQiOjE1OTEzMzUxMjQsImlzcyI6Imh0dHBzOi8vY2xvdWQuZ" \
      "29vZ2xlLmNvbS9pYXAiLCJzdWIiOiJhY2NvdW50cy5nb29nbGUuY29tOjExMzc3OTI1ODA4" \
      "MTE5ODAwNDY5NCJ9.2BlagZOoonmX35rNY-KPbONiVzFAdNXKRGkX45uGFXeHryjKgv--K6" \
      "siL8syeCFXzHvgmWpJk31sEt4YLxPKvQ"
    }
    let(:iap_jwk_body) {
      <<~JWK
      {
        "keys" : [
          {
              "alg" : "ES256",
              "crv" : "P-256",
              "kid" : "LYyP2g",
              "kty" : "EC",
              "use" : "sig",
              "x" : "SlXFFkJ3JxMsXyXNrqzE3ozl_0913PmNbccLLWfeQFU",
              "y" : "GLSahrZfBErmMUcHP0MGaeVnJdBwquhrhQ8eP05NfCI"
          },
          {
              "alg" : "ES256",
              "crv" : "P-256",
              "kid" : "mpf0DA",
              "kty" : "EC",
              "use" : "sig",
              "x" : "fHEdeT3a6KaC1kbwov73ZwB_SiUHEyKQwUUtMCEn0aI",
              "y" : "QWOjwPhInNuPlqjxLQyhveXpWqOFcQPhZ3t-koMNbZI"
          },
          {
              "alg" : "ES256",
              "crv" : "P-256",
              "kid" : "b9vTLA",
              "kty" : "EC",
              "use" : "sig",
              "x" : "qCByTAvci-jRAD7uQSEhTdOs8iA714IbcY2L--YzynI",
              "y" : "WQY0uCoQyPSozWKGQ0anmFeOH5JNXiZa9i6SNqOcm7w"
          },
          {
              "alg" : "ES256",
              "crv" : "P-256",
              "kid" : "0oeLcQ",
              "kty" : "EC",
              "use" : "sig",
              "x" : "MdhRXGEoGJLtBjQEIjnYLPkeci9rXnca2TffkI0Kac0",
              "y" : "9BoREHfX7g5OK8ELpA_4RcOnFCGSjfR4SGZpBo7juEY"
          },
          {
              "alg" : "ES256",
              "crv" : "P-256",
              "kid" : "g5X6ig",
              "kty" : "EC",
              "use" : "sig",
              "x" : "115LSuaFVzVROJiGfdPN1kT14Hv3P4RIjthfslZ010s",
              "y" : "-FAaRtO4yvrN4uJ89xwGWOEJcSwpLmFOtb0SDJxEAuc"
          }
        ]
      }
      JWK
    }
    let(:expected_aud) { "/projects/652562776798/apps/cloud-samples-tests-php-iap" }
    let(:unexpired_test_time) { Time.at 1591335143 }
    let(:expired_test_time) { unexpired_test_time + 86400 }

    after do
      WebMock.reset!
      Google::Auth::IDTokens.forget_sources!
    end

    it "verifies a good token with iss and aud checks" do
      stub_request(:get, Google::Auth::IDTokens::IAP_JWK_URL).to_return(body: iap_jwk_body)
      Time.stub :now, unexpired_test_time do
        Google::Auth::IDTokens.verify_iap iap_token, aud: expected_aud
      end
    end

    it "fails to verify a bad token" do
      stub_request(:get, Google::Auth::IDTokens::IAP_JWK_URL).to_return(body: iap_jwk_body)
      Time.stub :now, unexpired_test_time do
        assert_raises Google::Auth::IDTokens::SignatureError do
          Google::Auth::IDTokens.verify_iap "#{iap_token}x"
        end
      end
    end

    it "fails to verify a token with the wrong aud" do
      stub_request(:get, Google::Auth::IDTokens::IAP_JWK_URL).to_return(body: iap_jwk_body)
      Time.stub :now, unexpired_test_time do
        assert_raises Google::Auth::IDTokens::AudienceMismatchError do
          Google::Auth::IDTokens.verify_iap iap_token, aud: ["hello", "world"]
        end
      end
    end

    it "fails to verify a token with the wrong azp" do
      stub_request(:get, Google::Auth::IDTokens::IAP_JWK_URL).to_return(body: iap_jwk_body)
      Time.stub :now, unexpired_test_time do
        assert_raises Google::Auth::IDTokens::AuthorizedPartyMismatchError do
          Google::Auth::IDTokens.verify_iap iap_token, azp: "hello"
        end
      end
    end

    it "fails to verify a token with the wrong issuer" do
      stub_request(:get, Google::Auth::IDTokens::IAP_JWK_URL).to_return(body: iap_jwk_body)
      Time.stub :now, unexpired_test_time do
        assert_raises Google::Auth::IDTokens::IssuerMismatchError do
          Google::Auth::IDTokens.verify_iap iap_token, iss: "hello"
        end
      end
    end

    it "fails to verify an expired token" do
      stub_request(:get, Google::Auth::IDTokens::IAP_JWK_URL).to_return(body: iap_jwk_body)
      Time.stub :now, expired_test_time do
        assert_raises Google::Auth::IDTokens::ExpiredTokenError do
          Google::Auth::IDTokens.verify_iap iap_token
        end
      end
    end
  end
end
