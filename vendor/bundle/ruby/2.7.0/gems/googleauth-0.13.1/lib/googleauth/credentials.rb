# Copyright 2017, Google Inc.
# All rights reserved.
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

require "forwardable"
require "json"
require "signet/oauth_2/client"

require "googleauth/credentials_loader"

module Google
  module Auth
    ##
    # Credentials is responsible for representing the authentication when connecting to an API. This
    # class is also intended to be inherited by API-specific classes.
    class Credentials
      ##
      # The default token credential URI to be used when none is provided during initialization.
      TOKEN_CREDENTIAL_URI = "https://oauth2.googleapis.com/token".freeze

      ##
      # The default target audience ID to be used when none is provided during initialization.
      AUDIENCE = "https://oauth2.googleapis.com/token".freeze

      @audience = @scope = @target_audience = @env_vars = @paths = nil

      ##
      # The default token credential URI to be used when none is provided during initialization.
      # The URI is the authorization server's HTTP endpoint capable of issuing tokens and
      # refreshing expired tokens.
      #
      # @return [String]
      #
      def self.token_credential_uri
        return @token_credential_uri unless @token_credential_uri.nil?

        const_get :TOKEN_CREDENTIAL_URI if const_defined? :TOKEN_CREDENTIAL_URI
      end

      ##
      # Set the default token credential URI to be used when none is provided during initialization.
      #
      # @param [String] new_token_credential_uri
      # @return [String]
      #
      def self.token_credential_uri= new_token_credential_uri
        @token_credential_uri = new_token_credential_uri
      end

      ##
      # The default target audience ID to be used when none is provided during initialization.
      # Used only by the assertion grant type.
      #
      # @return [String]
      #
      def self.audience
        return @audience unless @audience.nil?

        const_get :AUDIENCE if const_defined? :AUDIENCE
      end

      ##
      # Sets the default target audience ID to be used when none is provided during initialization.
      #
      # @param [String] new_audience
      # @return [String]
      #
      def self.audience= new_audience
        @audience = new_audience
      end

      ##
      # The default scope to be used when none is provided during initialization.
      # A scope is an access range defined by the authorization server.
      # The scope can be a single value or a list of values.
      #
      # Either {#scope} or {#target_audience}, but not both, should be non-nil.
      # If {#scope} is set, this credential will produce access tokens.
      # If {#target_audience} is set, this credential will produce ID tokens.
      #
      # @return [String, Array<String>]
      #
      def self.scope
        return @scope unless @scope.nil?

        Array(const_get(:SCOPE)).flatten.uniq if const_defined? :SCOPE
      end

      ##
      # Sets the default scope to be used when none is provided during initialization.
      #
      # Either {#scope} or {#target_audience}, but not both, should be non-nil.
      # If {#scope} is set, this credential will produce access tokens.
      # If {#target_audience} is set, this credential will produce ID tokens.
      #
      # @param [String, Array<String>] new_scope
      # @return [String, Array<String>]
      #
      def self.scope= new_scope
        new_scope = Array new_scope unless new_scope.nil?
        @scope = new_scope
      end

      ##
      # The default final target audience for ID tokens, to be used when none
      # is provided during initialization.
      #
      # Either {#scope} or {#target_audience}, but not both, should be non-nil.
      # If {#scope} is set, this credential will produce access tokens.
      # If {#target_audience} is set, this credential will produce ID tokens.
      #
      # @return [String]
      #
      def self.target_audience
        @target_audience
      end

      ##
      # Sets the default final target audience for ID tokens, to be used when none
      # is provided during initialization.
      #
      # Either {#scope} or {#target_audience}, but not both, should be non-nil.
      # If {#scope} is set, this credential will produce access tokens.
      # If {#target_audience} is set, this credential will produce ID tokens.
      #
      # @param [String] new_target_audience
      #
      def self.target_audience= new_target_audience
        @target_audience = new_target_audience
      end

      ##
      # The environment variables to search for credentials. Values can either be a file path to the
      # credentials file, or the JSON contents of the credentials file.
      #
      # @return [Array<String>]
      #
      def self.env_vars
        return @env_vars unless @env_vars.nil?

        # Pull values when PATH_ENV_VARS or JSON_ENV_VARS constants exists.
        tmp_env_vars = []
        tmp_env_vars << const_get(:PATH_ENV_VARS) if const_defined? :PATH_ENV_VARS
        tmp_env_vars << const_get(:JSON_ENV_VARS) if const_defined? :JSON_ENV_VARS
        tmp_env_vars.flatten.uniq
      end

      ##
      # Sets the environment variables to search for credentials.
      #
      # @param [Array<String>] new_env_vars
      # @return [Array<String>]
      #
      def self.env_vars= new_env_vars
        new_env_vars = Array new_env_vars unless new_env_vars.nil?
        @env_vars = new_env_vars
      end

      ##
      # The file paths to search for credentials files.
      #
      # @return [Array<String>]
      #
      def self.paths
        return @paths unless @paths.nil?

        tmp_paths = []
        # Pull in values is the DEFAULT_PATHS constant exists.
        tmp_paths << const_get(:DEFAULT_PATHS) if const_defined? :DEFAULT_PATHS
        tmp_paths.flatten.uniq
      end

      ##
      # Set the file paths to search for credentials files.
      #
      # @param [Array<String>] new_paths
      # @return [Array<String>]
      #
      def self.paths= new_paths
        new_paths = Array new_paths unless new_paths.nil?
        @paths = new_paths
      end

      ##
      # The Signet::OAuth2::Client object the Credentials instance is using.
      #
      # @return [Signet::OAuth2::Client]
      #
      attr_accessor :client

      ##
      # Identifier for the project the client is authenticating with.
      #
      # @return [String]
      #
      attr_reader :project_id

      ##
      # Identifier for a separate project used for billing/quota, if any.
      #
      # @return [String,nil]
      #
      attr_reader :quota_project_id

      # @private Delegate client methods to the client object.
      extend Forwardable

      ##
      # @!attribute [r] token_credential_uri
      #   @return [String] The token credential URI. The URI is the authorization server's HTTP
      #     endpoint capable of issuing tokens and refreshing expired tokens.
      #
      # @!attribute [r] audience
      #   @return [String] The target audience ID when issuing assertions. Used only by the
      #     assertion grant type.
      #
      # @!attribute [r] scope
      #   @return [String, Array<String>] The scope for this client. A scope is an access range
      #     defined by the authorization server. The scope can be a single value or a list of values.
      #
      # @!attribute [r] target_audience
      #   @return [String] The final target audience for ID tokens returned by this credential.
      #
      # @!attribute [r] issuer
      #   @return [String] The issuer ID associated with this client.
      #
      # @!attribute [r] signing_key
      #   @return [String, OpenSSL::PKey] The signing key associated with this client.
      #
      # @!attribute [r] updater_proc
      #   @return [Proc] Returns a reference to the {Signet::OAuth2::Client#apply} method,
      #     suitable for passing as a closure.
      #
      def_delegators :@client,
                     :token_credential_uri, :audience,
                     :scope, :issuer, :signing_key, :updater_proc, :target_audience

      ##
      # Creates a new Credentials instance with the provided auth credentials, and with the default
      # values configured on the class.
      #
      # @param [String, Hash, Signet::OAuth2::Client] keyfile
      #   The keyfile can be provided as one of the following:
      #
      #   * The path to a JSON keyfile (as a +String+)
      #   * The contents of a JSON keyfile (as a +Hash+)
      #   * A +Signet::OAuth2::Client+ object
      # @param [Hash] options
      #   The options for configuring the credentials instance. The following is supported:
      #
      #   * +:scope+ - the scope for the client
      #   * +"project_id"+ (and optionally +"project"+) - the project identifier for the client
      #   * +:connection_builder+ - the connection builder to use for the client
      #   * +:default_connection+ - the default connection to use for the client
      #
      def initialize keyfile, options = {}
        verify_keyfile_provided! keyfile
        @project_id = options["project_id"] || options["project"]
        @quota_project_id = options["quota_project_id"]
        if keyfile.is_a? Signet::OAuth2::Client
          update_from_signet keyfile
        elsif keyfile.is_a? Hash
          update_from_hash keyfile, options
        else
          update_from_filepath keyfile, options
        end
        CredentialsLoader.warn_if_cloud_sdk_credentials @client.client_id
        @project_id ||= CredentialsLoader.load_gcloud_project_id
        @client.fetch_access_token!
        @env_vars = nil
        @paths = nil
        @scope = nil
      end

      ##
      # Creates a new Credentials instance with auth credentials acquired by searching the
      # environment variables and paths configured on the class, and with the default values
      # configured on the class.
      #
      # The auth credentials are searched for in the following order:
      #
      # 1. configured environment variables (see {Credentials.env_vars})
      # 2. configured default file paths (see {Credentials.paths})
      # 3. application default (see {Google::Auth.get_application_default})
      #
      # @param [Hash] options
      #   The options for configuring the credentials instance. The following is supported:
      #
      #   * +:scope+ - the scope for the client
      #   * +"project_id"+ (and optionally +"project"+) - the project identifier for the client
      #   * +:connection_builder+ - the connection builder to use for the client
      #   * +:default_connection+ - the default connection to use for the client
      #
      # @return [Credentials]
      #
      def self.default options = {}
        # First try to find keyfile file or json from environment variables.
        client = from_env_vars options

        # Second try to find keyfile file from known file paths.
        client ||= from_default_paths options

        # Finally get instantiated client from Google::Auth
        client ||= from_application_default options
        client
      end

      ##
      # @private Lookup Credentials from environment variables.
      def self.from_env_vars options
        env_vars.each do |env_var|
          str = ENV[env_var]
          next if str.nil?
          return new str, options if ::File.file? str
          return new ::JSON.parse(str), options rescue nil
        end
        nil
      end

      ##
      # @private Lookup Credentials from default file paths.
      def self.from_default_paths options
        paths
          .select { |p| ::File.file? p }
          .each do |file|
            return new file, options
          end
        nil
      end

      ##
      # @private Lookup Credentials using Google::Auth.get_application_default.
      def self.from_application_default options
        scope = options[:scope] || self.scope
        auth_opts = { target_audience: options[:target_audience] || target_audience }
        client = Google::Auth.get_application_default scope, auth_opts
        new client, options
      end

      private_class_method :from_env_vars,
                           :from_default_paths,
                           :from_application_default

      protected

      # Verify that the keyfile argument is provided.
      def verify_keyfile_provided! keyfile
        return unless keyfile.nil?
        raise "The keyfile passed to Google::Auth::Credentials.new was nil."
      end

      # Verify that the keyfile argument is a file.
      def verify_keyfile_exists! keyfile
        exists = ::File.file? keyfile
        raise "The keyfile '#{keyfile}' is not a valid file." unless exists
      end

      # Initializes the Signet client.
      def init_client keyfile, connection_options = {}
        client_opts = client_options keyfile
        Signet::OAuth2::Client.new(client_opts)
                              .configure_connection(connection_options)
      end

      # returns a new Hash with string keys instead of symbol keys.
      def stringify_hash_keys hash
        Hash[hash.map { |k, v| [k.to_s, v] }]
      end

      def client_options options
        # Keyfile options have higher priority over constructor defaults
        options["token_credential_uri"] ||= self.class.token_credential_uri
        options["audience"] ||= self.class.audience
        options["scope"] ||= self.class.scope
        options["target_audience"] ||= self.class.target_audience

        if !Array(options["scope"]).empty? && options["target_audience"]
          raise ArgumentError, "Cannot specify both scope and target_audience"
        end

        needs_scope = options["target_audience"].nil?
        # client options for initializing signet client
        { token_credential_uri: options["token_credential_uri"],
          audience:             options["audience"],
          scope:                (needs_scope ? Array(options["scope"]) : nil),
          target_audience:      options["target_audience"],
          issuer:               options["client_email"],
          signing_key:          OpenSSL::PKey::RSA.new(options["private_key"]) }
      end

      def update_from_signet client
        @project_id ||= client.project_id if client.respond_to? :project_id
        @quota_project_id ||= client.quota_project_id if client.respond_to? :quota_project_id
        @client = client
      end

      def update_from_hash hash, options
        hash = stringify_hash_keys hash
        hash["scope"] ||= options[:scope]
        hash["target_audience"] ||= options[:target_audience]
        @project_id ||= (hash["project_id"] || hash["project"])
        @quota_project_id ||= hash["quota_project_id"]
        @client = init_client hash, options
      end

      def update_from_filepath path, options
        verify_keyfile_exists! path
        json = JSON.parse ::File.read(path)
        json["scope"] ||= options[:scope]
        json["target_audience"] ||= options[:target_audience]
        @project_id ||= (json["project_id"] || json["project"])
        @quota_project_id ||= json["quota_project_id"]
        @client = init_client json, options
      end
    end
  end
end
