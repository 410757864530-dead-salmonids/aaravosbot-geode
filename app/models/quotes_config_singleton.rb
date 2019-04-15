# Model: QuotesConfig (singleton)


# Holds the config for the quote feature. Has a single field for the number of cameras needed to quote.
class Bot::Models::QuotesConfig < Sequel::Model(:quotes_config)
  private_class_method :new, :create

  # Returns the only instance of this class
  def self.instance
    first || create
  end

  # Put the model details (associations, hooks, etc.) here.
  # For information on model details, visit https://github.com/jeremyevans/sequel#sequel-models
end