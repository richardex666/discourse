# frozen_string_literal: true

module Chat
  # Service responsible for marking messages in a thread
  # as read. For now this just marks any mentions in the thread
  # as read, but as we add user tracking state to threads it
  # will work in a similar way to Chat::UpdateUserLastRead
  #
  # @example
  #  Chat::UpdateUserThreadLastRead.call(channel_id: 2, thread_id: 3, guardian: guardian)
  #
  class UpdateUserThreadLastRead
    include ::Service::Base

    # @!method call(channel_id:, thread_id:, guardian:)
    #   @param [Integer] channel_id
    #   @param [Integer] thread_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    model :thread
    policy :invalid_access
    step :mark_associated_mentions_as_read
    step :publish_new_last_read_to_clients

    # @!visibility private
    class Contract
      attribute :thread_id, :integer
      attribute :channel_id, :integer

      validates :thread_id, :channel_id, presence: true
    end

    private

    def fetch_thread(contract:, **)
      ::Chat::Thread.find_by(id: contract.thread_id, channel_id: contract.channel_id)
    end

    def invalid_access(guardian:, thread:, **)
      guardian.can_join_chat_channel?(thread.channel)
    end

    def mark_associated_mentions_as_read(thread:, guardian:, **)
      ::Chat::Action::MarkMentionsRead.call(
        guardian.user,
        channel_ids: [thread.channel_id],
        thread_id: thread.id,
      )
    end

    def publish_new_last_read_to_clients(guardian:, thread:, **)
      ::Chat::Publisher.publish_user_tracking_state(
        guardian.user,
        thread.channel_id,
        thread.replies.last.id,
      )
    end
  end
end
