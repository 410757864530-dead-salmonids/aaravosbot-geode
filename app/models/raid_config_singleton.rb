# Model: RaidConfig (singleton)


# Holds the config for raid protection functionality. Has two fields for the number of users that must join in the
# given number of seconds to trigger raid mode.
class Bot::Models::RaidConfig < Sequel::Model(:raid_config)
  private_class_method :new, :create

  # Returns the only instance of this class
  def self.instance
    first || create
  end
end