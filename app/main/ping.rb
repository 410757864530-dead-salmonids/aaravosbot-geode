# Crystal: Ping


# Contains a simple ping command.
module Bot::Ping
  extend Discordrb::Commands::CommandContainer

  # Ping command
  command :ping do |event|
    before = Time.now
    msg = event.respond '**PongChamp**'
    after = Time.now
    msg.edit "**PongChamp** | #{((after - before) * 1000).round}ms response time"
  end

  # Help command info
  module HelpInfo
    extend HelpCommand

    # +ping
    command_info(
        name: :ping,
        blurb: 'Pings the bot.',
        permission: :user,
        info: ['Pings the bot, showing the response time.']
    )
  end
end