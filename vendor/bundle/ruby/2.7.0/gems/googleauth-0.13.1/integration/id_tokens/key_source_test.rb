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

describe Google::Auth::IDTokens do
  describe "key source" do
    let(:legacy_oidc_key_source) {
      Google::Auth::IDTokens::X509CertHttpKeySource.new "https://www.googleapis.com/oauth2/v1/certs"
    }
    let(:oidc_key_source) { Google::Auth::IDTokens.oidc_key_source }
    let(:iap_key_source) { Google::Auth::IDTokens.iap_key_source }

    it "Gets real keys from the OAuth2 V1 cert URL" do
      keys = legacy_oidc_key_source.refresh_keys
      refute_empty keys
      keys.each do |key|
        assert_kind_of OpenSSL::PKey::RSA, key.key
        refute key.key.private?
        assert_equal "RS256", key.algorithm
      end
    end

    it "Gets real keys from the OAuth2 V3 cert URL" do
      keys = oidc_key_source.refresh_keys
      refute_empty keys
      keys.each do |key|
        assert_kind_of OpenSSL::PKey::RSA, key.key
        refute key.key.private?
        assert_equal "RS256", key.algorithm
      end
    end

    it "Gets the same keys from the OAuth2 V1 and V3 cert URLs" do
      keys_v1 = legacy_oidc_key_source.refresh_keys.map(&:key).map(&:export).sort
      keys_v3 = oidc_key_source.refresh_keys.map(&:key).map(&:export).sort
      assert_equal keys_v1, keys_v3
    end

    it "Gets real keys from the IAP public key URL" do
      keys = iap_key_source.refresh_keys
      refute_empty keys
      keys.each do |key|
        assert_kind_of OpenSSL::PKey::EC, key.key
        assert_equal "ES256", key.algorithm
      end
    end
  end
end
