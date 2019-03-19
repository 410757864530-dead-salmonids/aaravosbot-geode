# Model: ChatUser


# A user currently chatting with server staff. Has many ChatMessages (used to log the chat) and fields for user's ID,
# staff contact channel ID and the chat's start time
class Bot::Models::ChatUser < Sequel::Model
  unrestrict_primary_key

  one_to_many :chat_messages
end