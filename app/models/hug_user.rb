# Model: HugUser


# A user giving or receiving hugs. Has fields for the number of hugs user has given and received.
class Bot::Models::HugUser < Sequel::Model
  unrestrict_primary_key
end