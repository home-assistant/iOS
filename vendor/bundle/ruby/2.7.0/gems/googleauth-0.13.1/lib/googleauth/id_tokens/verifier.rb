# frozen_string_literal: true

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

require "jwt"

module Google
  module Auth
    module IDTokens
      ##
      # An object that can verify ID tokens.
      #
      # A verifier maintains a set of default settings, including the key
      # source and fields to verify. However, individual verification calls can
      # override any of these settings.
      #
      class Verifier
        ##
        # Create a verifier.
        #
        # @param key_source [key source] The default key source to use. All
        #     verification calls must have a key source, so if no default key
        #     source is provided here, then calls to {#verify} _must_ provide
        #     a key source.
        # @param aud [String,nil] The default audience (`aud`) check, or `nil`
        #     for no check.
        # @param azp [String,nil] The default authorized party (`azp`) check,
        #     or `nil` for no check.
        # @param iss [String,nil] The default issuer (`iss`) check, or `nil`
        #     for no check.
        #
        def initialize key_source: nil,
                       aud:        nil,
                       azp:        nil,
                       iss:        nil
          @key_source = key_source
          @aud = aud
          @azp = azp
          @iss = iss
        end

        ##
        # Verify the given token.
        #
        # @param token [String] the ID token to verify.
        # @param key_source [key source] If given, override the key source.
        # @param aud [String,nil] If given, override the `aud` check.
        # @param azp [String,nil] If given, override the `azp` check.
        # @param iss [String,nil] If given, override the `iss` check.
        #
        # @return [Hash] the decoded payload, if verification succeeded.
        # @raise [KeySourceError] if the key source failed to obtain public keys
        # @raise [VerificationError] if the token verification failed.
        #     Additional data may be available in the error subclass and message.
        #
        def verify token,
                   key_source: :default,
                   aud:        :default,
                   azp:        :default,
                   iss:        :default
          key_source = @key_source if key_source == :default
          aud = @aud if aud == :default
          azp = @azp if azp == :default
          iss = @iss if iss == :default

          raise KeySourceError, "No key sources" unless key_source
          keys = key_source.current_keys
          payload = decode_token token, keys, aud, azp, iss
          unless payload
            keys = key_source.refresh_keys
            payload = decode_token token, keys, aud, azp, iss
          end
          raise SignatureError, "Token not verified as issued by Google" unless payload
          payload
        end

        private

        def decode_token token, keys, aud, azp, iss
          payload = nil
          keys.find do |key|
            begin
              options = { algorithms: key.algorithm }
              decoded_token = JWT.decode token, key.key, true, options
              payload = decoded_token.first
            rescue JWT::ExpiredSignature
              raise ExpiredTokenError, "Token signature is expired"
            rescue JWT::DecodeError
              nil # Try the next key
            end
          end

          normalize_and_verify_payload payload, aud, azp, iss
        end

        def normalize_and_verify_payload payload, aud, azp, iss
          return nil unless payload

          # Map the legacy "cid" claim to the canonical "azp"
          payload["azp"] ||= payload["cid"] if payload.key? "cid"

          # Payload content validation
          if aud && (Array(aud) & Array(payload["aud"])).empty?
            raise AudienceMismatchError, "Token aud mismatch: #{payload['aud']}"
          end
          if azp && (Array(azp) & Array(payload["azp"])).empty?
            raise AuthorizedPartyMismatchError, "Token azp mismatch: #{payload['azp']}"
          end
          if iss && (Array(iss) & Array(payload["iss"])).empty?
            raise IssuerMismatchError, "Token iss mismatch: #{payload['iss']}"
          end

          payload
        end
      end
    end
  end
end
