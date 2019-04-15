# Model: FloodConfig (singleton)


# Holds the config for flood protection functionality. Has two fields for the number of messages that must be sent
# by a user in the given number of seconds to trigger message deletion.
class Bot::Models::FloodConfig < Sequel::Model(:flood_config)
  private_class_method :new, :create

  # Returns the only instance of this class
  def self.instance
    first || create
  end

  # Put the model details (associations, hooks, etc.) here.
  # For information on model details, visit https://github.com/jeremyevans/sequel#sequel-models
end