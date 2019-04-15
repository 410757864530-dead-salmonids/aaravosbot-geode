# Crystal: Quotes


# Manages the message quoting feature of the bot.
module Bot::Quotes
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models

  extend Convenience
  include Constants

  # #aaravos_storybook ID
  STORYBOOK_ID = 506866876417048586

  # Set cameras needed to quote message
  command :asbcams do |event, arg|
    # Break unless user is moderator
    break unless event.user.has_permission?(:moderator)

    config = QuotesConfig.instance

    # If argument is given, set cams needed to quote, save to database and respond to user
    if arg
      config.cameras = arg.to_i
      config.save
      event << "**Set number of camera reactions required to quote a message to #{arg.to_i}.**"

    # Otherwise, respond with current cams needed to quote
    else
      event << "**#{pl(config.cameras, 'cameras')}** are needed to quote a message."
    end
  end

  # Quote a message when it has reached cam count
  reaction_add(emoji: '📷') do |event|
    # Skips unless the message has exactly the number of cameras to be quoted
    next unless event.message.reactions[[0x1F4F7].pack('U*')].count == QuotesConfig.instance.cameras

    # Skip if message has already been quoted
    next if QuotedMessage[event.message.id]

    # Sends embed to #aaravos_storybook with a quote of the message
    Bot::BOT.channel(STORYBOOK_ID).send_embed do |embed|
      embed.author = {
          name: "#{event.message.author.on(SERVER).display_name} (#{event.message.author.distinct})",
          icon_url: event.message.author.avatar_url
      }
      embed.color = 0xFFD700
      embed.description = event.message.content
      embed.image = Discordrb::Webhooks::EmbedImage.new(url: event.message.attachments[0].url) unless event.message.attachments == []
      embed.timestamp = event.message.timestamp.getgm
      embed.footer = {text: "##{event.message.channel.name}"}
    end

    # Add message to database
    QuotedMessage.create(id: event.message.id)

    # Delete all reactions on message
    event.message.delete_all_reactions
  end

  # Help command info
  module HelpInfo
    extend HelpCommand

    # +asbcams
    command_info(
        name: :asbcams,
        blurb: 'Displays/sets cameras needed for a quote.',
        permission: :moderator,
        info: ['Displays or sets the number of cameras required to quote a message in <#506866876417048586>.'],
        usage: [
            [nil, 'Displays the current number of cameras required to quote a message.'],
            ['<number>', 'Sets the number of cameras required to quote to the specified value.']
        ]
    )
  end
end