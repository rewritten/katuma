module Onboarding
  module Api
    module V1
      class InvitationsController < ApplicationController
        before_action :authenticate, only: [:bulk]
        before_action :load_group, only: [:bulk]
        before_action :load_invitation, only: [:show, :accept]

        # Creates invitations in bulk
        #
        # POST /api/v1/invitations/bulk
        #
        def bulk
          authorize @group

          if bulk_params[:emails].blank?
            return render(
              status: :bad_request,
              json: { errors: { emails: t('onboarding.invitation.bulk.errors.empty') } }
            )
          end

          valid_emails = extract_emails(bulk_params[:emails])

          if valid_emails.any?
            InvitationService.new.bulk_invite!(@group, current_user, valid_emails)

            head :accepted
          else
            render(
              status: :bad_request,
              json: { errors: { emails: t('onboarding.invitation.bulk.errors.invalid') } }
            )
          end
        end

        # GET /invitations/:token
        #
        def show
          head :bad_request if current_user

          render status: :ok, json: { email: @invitation.email }
        end

        # POST /api/v1/invitations/accept/:token
        #
        def accept
          user = InvitationService.new.accept!(@invitation, accept_params)

          if user.valid? && user.persisted?
            render json: ::Account::UserSerializer.new(user)
          else
            render(
              status: :bad_request,
              json: user.errors.to_json
            )
          end
        end

        private

        # :emails is a String containing a comma separated list of email addresses
        #
        def bulk_params
          params.require(:group_id)
          params.permit(:group_id, :emails)
        end

        def accept_params
          params.require(:token)
          params.permit(:token, :username, :first_name, :last_name, :password, :password_confirmation)
        end

        def load_group
          @group = ::Onboarding::Group.find_by_id(bulk_params[:group_id])

          head :not_found unless @group
        end

        def load_invitation
          @invitation = Invitation.find_by_token(accept_params[:token])

          head :not_found unless @invitation
        end

        # Filters only the valid emails, we just pick the first 100 valid emails
        # We don't want to allow infinite invitations.
        #
        # @param emails [String] comma separated email addresses
        # @return [Array<String>]
        def extract_emails(emails)
          return [] if emails.blank?

          emails.
            split(',').
            select { |email| ::EmailValidator.valid?(email) }.
            first(100)
        end
      end
    end
  end
end
