# Model: QuotedMessage


# Represents a message that has been quoted. Has the message ID as the primary key and the channel ID as a field.
class Bot::Models::QuotedMessage < Sequel::Model
  unrestrict_primary_key
end