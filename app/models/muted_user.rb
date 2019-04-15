# Model: MutedUser


# An instance of a muted user. Primary key is user's ID and holds a single field with the time at which mute ends.
class Bot::Models::MutedUser < Sequel::Model
  unrestrict_primary_key
end