module GrapeOAuth2
  module Mongoid
    module AccessToken
      extend ActiveSupport::Concern

      included do
        include ::Mongoid::Document
        include ::Mongoid::Timestamps

        field :resource_owner_id, type: BSON::ObjectId
        field :client_id, type: BSON::ObjectId

        belongs_to :client, class_name: 'Application', foreign_key: :client_id, optional: true
        belongs_to :resource_owner, class_name: 'User', foreign_key: :resource_owner_id, optional: true

        field :token, type: String
        field :refresh_token, type: String
        field :scopes, type: String

        field :expires_at, type: DateTime
        field :revoked_at, type: DateTime

        index({ token: 1 }, unique: true)
        index({ refresh_token: 1 }, unique: true, sparse: true)

        before_validation :setup_expiration, on: :create
        before_validation :generate_tokens, on: :create

        class << self
          def create_for(client, resource_owner, scopes = nil)
            create(
              client: client,
              resource_owner: resource_owner,
              scopes: scopes.to_s
            )
          end

          def authenticate(token, type: :access_token)
            if type && type.to_sym == :refresh_token
              find_by(refresh_token: token.to_s)
            else
              find_by(token: token.to_s)
            end
          end
        end

        def expired?
          !expires_at.nil? && Time.now.utc > expires_at
        end

        def revoked?
          !revoked_at.nil? && revoked_at <= Time.now.utc
        end

        def revoke!(revoked_at = Time.now)
          update_attribute :revoked_at, revoked_at.utc
        end

        def to_bearer_token
          {
            access_token: token,
            expires_in: expires_at && GrapeOAuth2.config.access_token_lifetime.to_i,
            refresh_token: refresh_token,
            scope: scopes
          }
        end

        protected

        def generate_tokens
          self.token = GrapeOAuth2.config.token_generator.generate(attributes) if token.blank?
          self.refresh_token = GrapeOAuth2::UniqueToken.generate if GrapeOAuth2.config.issue_refresh_token
        end

        def setup_expiration
          expires_in = GrapeOAuth2.config.access_token_lifetime
          self.expires_at = Time.now + expires_in if expires_at.nil? && !expires_in.nil?
        end
      end
    end
  end
end
