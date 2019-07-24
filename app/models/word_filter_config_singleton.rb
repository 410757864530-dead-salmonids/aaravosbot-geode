# Model: WordFilterConfig (singleton)


# TODO Write a description of the model here.
class Bot::Models::WordFilterConfig < Sequel::Model(:word_filter_config)
  private_class_method :new, :create

  # Returns the only instance of this class
  def self.instance
    first || create
  end

  one_to_many :wfc_disabled_channels
end