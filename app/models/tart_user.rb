# Model: TartUser


# A user giving or receiving jelly tarts. Has fields for the number of jelly tarts user has given and received.
class Bot::Models::TartUser < Sequel::Model
  unrestrict_primary_key
end