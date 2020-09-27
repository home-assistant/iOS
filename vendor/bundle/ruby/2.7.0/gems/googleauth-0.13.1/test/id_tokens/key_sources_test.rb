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

require "openssl"

describe Google::Auth::IDTokens do
  describe "StaticKeySource" do
    let(:key1) { Google::Auth::IDTokens::KeyInfo.new id: "1234", key: :key1, algorithm: "RS256" }
    let(:key2) { Google::Auth::IDTokens::KeyInfo.new id: "5678", key: :key2, algorithm: "ES256" }
    let(:keys) { [key1, key2] }
    let(:source) { Google::Auth::IDTokens::StaticKeySource.new keys }

    it "returns a static set of keys" do
      assert_equal keys, source.current_keys
    end

    it "does not change on refresh" do
      assert_equal keys, source.refresh_keys
    end
  end

  describe "HttpKeySource" do
    let(:certs_uri) { "https://example.com/my-certs" }
    let(:certs_body) { "{}" }

    it "raises an error when failing to parse json from the site" do
      source = Google::Auth::IDTokens::HttpKeySource.new certs_uri
      stub = stub_request(:get, certs_uri).to_return(body: "whoops")
      error = assert_raises Google::Auth::IDTokens::KeySourceError do
        source.refresh_keys
      end
      assert_equal "Unable to parse JSON", error.message
      assert_requested stub
    end

    it "downloads data but gets no keys" do
      source = Google::Auth::IDTokens::HttpKeySource.new certs_uri
      stub = stub_request(:get, certs_uri).to_return(body: certs_body)
      keys = source.refresh_keys
      assert_empty keys
      assert_requested stub
    end
  end

  describe "X509CertHttpKeySource" do
    let(:certs_uri) { "https://example.com/my-certs" }
    let(:key1) { OpenSSL::PKey::RSA.new 2048 }
    let(:key2) { OpenSSL::PKey::RSA.new 2048 }
    let(:cert1) { generate_cert key1 }
    let(:cert2) { generate_cert key2 }
    let(:id1) { "1234" }
    let(:id2) { "5678" }
    let(:certs_body) { JSON.dump({ id1 => cert1.to_pem, id2 => cert2.to_pem }) }

    after do
      WebMock.reset!
    end

    def generate_cert key
      cert = OpenSSL::X509::Certificate.new
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse "/C=BE/O=Test/OU=Test/CN=Test"
      cert.not_before = Time.now
      cert.not_after = Time.now + 365 * 24 * 60 * 60
      cert.public_key = key.public_key
      cert.serial = 0x0
      cert.version = 2
      cert.sign key, OpenSSL::Digest::SHA1.new
      cert
    end

    it "raises an error when failing to reach the site" do
      source = Google::Auth::IDTokens::X509CertHttpKeySource.new certs_uri
      stub = stub_request(:get, certs_uri).to_return(body: "whoops", status: 404)
      error = assert_raises Google::Auth::IDTokens::KeySourceError do
        source.refresh_keys
      end
      assert_equal "Unable to retrieve data from #{certs_uri}", error.message
      assert_requested stub
    end

    it "raises an error when failing to parse json from the site" do
      source = Google::Auth::IDTokens::X509CertHttpKeySource.new certs_uri
      stub = stub_request(:get, certs_uri).to_return(body: "whoops")
      error = assert_raises Google::Auth::IDTokens::KeySourceError do
        source.refresh_keys
      end
      assert_equal "Unable to parse JSON", error.message
      assert_requested stub
    end

    it "raises an error when failing to parse x509 from the site" do
      source = Google::Auth::IDTokens::X509CertHttpKeySource.new certs_uri
      stub = stub_request(:get, certs_uri).to_return(body: '{"hi": "whoops"}')
      error = assert_raises Google::Auth::IDTokens::KeySourceError do
        source.refresh_keys
      end
      assert_equal "Unable to parse X509 certificates", error.message
      assert_requested stub
    end

    it "gets the right certificates" do
      source = Google::Auth::IDTokens::X509CertHttpKeySource.new certs_uri
      stub = stub_request(:get, certs_uri).to_return(body: certs_body)
      keys = source.refresh_keys
      assert_equal id1, keys[0].id
      assert_equal id2, keys[1].id
      assert_equal key1.public_key.to_pem, keys[0].key.to_pem
      assert_equal key2.public_key.to_pem, keys[1].key.to_pem
      assert_equal "RS256", keys[0].algorithm
      assert_equal "RS256", keys[1].algorithm
      assert_requested stub
    end
  end

  describe "JwkHttpKeySource" do
    let(:jwk_uri) { "https://example.com/my-jwk" }
    let(:id1) { "fb8ca5b7d8d9a5c6c6788071e866c6c40f3fc1f9" }
    let(:id2) { "LYyP2g" }
    let(:jwk1) {
      {
        alg: "RS256",
        e:   "AQAB",
        kid: id1,
        kty: "RSA",
        n:   "zK8PHf_6V3G5rU-viUOL1HvAYn7q--dxMoUkt7x1rSWX6fimla-lpoYAKhFTLU" \
             "ELkRKy_6UDzfybz0P9eItqS2UxVWYpKYmKTQ08HgUBUde4GtO_B0SkSk8iLtGh" \
             "653UBBjgXmfzdfQEz_DsaWn7BMtuAhY9hpMtJye8LQlwaS8ibQrsC0j0GZM5KX" \
             "RITHwfx06_T1qqC_MOZRA6iJs-J2HNlgeyFuoQVBTY6pRqGXa-qaVsSG3iU-vq" \
             "NIciFquIq-xydwxLqZNksRRer5VAsSHf0eD3g2DX-cf6paSy1aM40svO9EfSvG" \
             "_07MuHafEE44RFvSZZ4ubEN9U7ALSjdw",
        use: "sig"
      }
    }
    let(:jwk2) {
      {
        alg: "ES256",
        crv: "P-256",
        kid: id2,
        kty: "EC",
        use: "sig",
        x:   "SlXFFkJ3JxMsXyXNrqzE3ozl_0913PmNbccLLWfeQFU",
        y:   "GLSahrZfBErmMUcHP0MGaeVnJdBwquhrhQ8eP05NfCI"
      }
    }
    let(:bad_type_jwk) {
      {
        alg: "RS256",
        kid: "hello",
        kty: "blah",
        use: "sig"
      }
    }
    let(:jwk_body) { JSON.dump({ keys: [jwk1, jwk2] }) }
    let(:bad_type_body) { JSON.dump({ keys: [bad_type_jwk] }) }

    after do
      WebMock.reset!
    end

    it "raises an error when failing to reach the site" do
      source = Google::Auth::IDTokens::JwkHttpKeySource.new jwk_uri
      stub = stub_request(:get, jwk_uri).to_return(body: "whoops", status: 404)
      error = assert_raises Google::Auth::IDTokens::KeySourceError do
        source.refresh_keys
      end
      assert_equal "Unable to retrieve data from #{jwk_uri}", error.message
      assert_requested stub
    end

    it "raises an error when failing to parse json from the site" do
      source = Google::Auth::IDTokens::JwkHttpKeySource.new jwk_uri
      stub = stub_request(:get, jwk_uri).to_return(body: "whoops")
      error = assert_raises Google::Auth::IDTokens::KeySourceError do
        source.refresh_keys
      end
      assert_equal "Unable to parse JSON", error.message
      assert_requested stub
    end

    it "raises an error when the json structure is malformed" do
      source = Google::Auth::IDTokens::JwkHttpKeySource.new jwk_uri
      stub = stub_request(:get, jwk_uri).to_return(body: '{"hi": "whoops"}')
      error = assert_raises Google::Auth::IDTokens::KeySourceError do
        source.refresh_keys
      end
      assert_equal "No keys found in jwk set", error.message
      assert_requested stub
    end

    it "raises an error when an unrecognized key type is encountered" do
      source = Google::Auth::IDTokens::JwkHttpKeySource.new jwk_uri
      stub = stub_request(:get, jwk_uri).to_return(body: bad_type_body)
      error = assert_raises Google::Auth::IDTokens::KeySourceError do
        source.refresh_keys
      end
      assert_equal "Cannot use key type blah", error.message
      assert_requested stub
    end

    it "gets the right keys" do
      source = Google::Auth::IDTokens::JwkHttpKeySource.new jwk_uri
      stub = stub_request(:get, jwk_uri).to_return(body: jwk_body)
      keys = source.refresh_keys
      assert_equal id1, keys[0].id
      assert_equal id2, keys[1].id
      assert_kind_of OpenSSL::PKey::RSA, keys[0].key
      assert_kind_of OpenSSL::PKey::EC, keys[1].key
      assert_equal "RS256", keys[0].algorithm
      assert_equal "ES256", keys[1].algorithm
      assert_requested stub
    end
  end
end
