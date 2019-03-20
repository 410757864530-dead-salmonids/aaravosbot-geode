# Crystal: Fun


# This crystal contains random fun commands.
module Bot::Fun
  extend Discordrb::Commands::CommandContainer
  include Bot::Models

  extend Convenience
  include Constants

  # Bucket for +genderator
  GENDERATOR_BUCKET = Bot::BOT.bucket(
      :genderator,
      limit:     1,
      time_span: 10
  )
  # Bucket for +hug and +jellytart
  HUG_TART_BUCKET = Bot::BOT.bucket(
      :hug_tart,
      limit:     1,
      time_span: 3
  )
  # Jade's ID
  JADE_ID = 139198446799290369

  # Predict user's gender with revolutionary technology
  command :genderator do |event|
    # If the rate limit has been hit, respond to user and break
    if (time = GENDERATOR_BUCKET.rate_limited?(event.user.id))
      event.send_temp("Please wait **#{pl(time.round, 'seconds')}**.", 3)
      break
    end

    gender_options = YAML.load_data! "#{ENV['DATA_PATH']}/gender_options.yml"

    # Responds to user with their 100% accurate gender
    event << "**Your gender is:** `#{gender_options.map(&:sample).join(' ')}`"
  end

  # Give another user a jelly tart
  command :jellytart, aliases: [:tart] do |event, *args|
    # Break unless user is valid and not the event user
    break unless (user = SERVER.get_user(args.join(' '))) &&
                 user != event.user

    # If the rate limit has been hit, respond to user and break
    if (time = HUG_TART_BUCKET.rate_limited?(event.user.id))
      event.send_temp("Please wait **#{pl(time.round, 'seconds')}**.", 3)
      break
    end

    giving_tart_user = TartUser[event.user.id] || TartUser.create(id: event.user.id)
    receiving_tart_user = TartUser[user.id] || TartUser.create(id: user.id)

    # Add one to the giving user's given count and receiving user's received count
    giving_tart_user.given += 1
    receiving_tart_user.received += 1

    # Save to database
    giving_tart_user.save
    receiving_tart_user.save

    # Respond to user
    event.respond(
        "<:tdpTartgasm:492743401616310272> | **#{event.user.name}** *has given* #{user.mention} *a jelly tart!*",
        false, # tts
        {
            author: {
                name:     "#{pl(giving_tart_user.given, 'tarts')} given | #{pl(giving_tart_user.received, 'tarts')} received",
                icon_url: event.user.avatar_url
            },
            color: 0xFFD700
        }
    )
  end

  # Give another user a hug
  command :hug do |event, *args|
    # Break unless user is valid and not the event user
    break unless (user = SERVER.get_user(args.join(' '))) &&
                 user != event.user

    # If the rate limit has been hit, respond to user and break
    if (time = HUG_TART_BUCKET.rate_limited?(event.user.id))
      event.send_temp("Please wait **#{pl(time.round, 'seconds')}**.", 3)
      break
    end

    giving_hug_user = HugUser[event.user.id] || HugUser.create(id: event.user.id)
    receiving_hug_user = HugUser[user.id] || HugUser.create(id: user.id)

    # Add one to the giving user's given count and receiving user's received count
    giving_hug_user.given += 1
    receiving_hug_user.received += 1

    # Save to database
    giving_hug_user.save
    receiving_hug_user.save

    # Respond to user
    event.respond(
        ":hugging: | **#{event.user.name}** *gives* #{user.mention} *a warm hug.*",
        false, # tts
        {
            author: {
                name:     "#{pl(giving_hug_user.given, 'hugs')} given - #{pl(giving_hug_user.received, 'hug')} received",
                icon_url: event.user.avatar_url
            },
            color: 0xFFD700
        }
    )
  end

  # "Ban" a user
  command :ban do |event, *args|
    # Break unless given user is valid
    break unless (user = SERVER.get_user(args.join(' ')))

    ban_scenarios = YAML.load_data!("#{ENV['DATA_PATH']}/ban_scenarios.yml")

    # Respond to command with a ban scenario
    "*#{ban_scenarios.sample.gsub('{user}', user.mention)}*"
  end

  # Make the bot say something
  command :say do |event, arg|
    # Break unless user is moderator or Jade
    break unless event.user.has_permission?(:moderator) ||
                 event.user.id == JADE_ID

    # If a valid channel argument was given, send the given message content to that channel unless no message was given
    if (channel = Bot::BOT.channel(arg.scan(/\d/).join))
      unless event.message.content[(arg.length + 6)..-1].empty?
        channel.send(event.message.content[(arg.length + 6)..-1])
      end

    # Otherwise, delete the event message and respond with the given message content in this channel
    else
      unless event.message.content[5..-1].empty?
        event.message.delete
        event << event.message.content[5..-1]
      end
    end
  end

  # Alias of +say
  command :s do |event, arg|
    # Break unless user is moderator or Jade
    break unless event.user.has_permission?(:moderator) ||
                 event.user.id == JADE_ID

    # If a valid channel argument was given, send the given message content to that channel unless no message was given
    if (channel = Bot::BOT.channel(arg.scan(/\d/).join))
      unless event.message.content[(arg.length + 4)..-1].empty?
        channel.send(event.message.content[(arg.length + 4)..-1])
      end

    # Otherwise, delete the event message and respond with the given message content in this channel
    else
      unless event.message.content[3..-1].empty?
        event.message.delete
        event << event.message.content[3..-1]
      end
    end
  end

  # Help command info
  module HelpInfo
    extend HelpCommand

    # +genderator
    command_info(
        name: :genderator,
        blurb: "What's your gender?",
        permission: :user,
        group: :fun,
        info: ["Carefully scans and analyzes the user's brainwaves through revolutionary technology and intelligently predicts what their gender is."]
    )

    # +jellytart
    command_info(
        name: :jellytart,
        blurb: 'Gives a jelly tart to someone.',
        permission: :user,
        info: ['Gives a jelly tart to a user of your choice. <:tdpTartgasm:492743401616310272>'],
        usage: [['<user>', 'Gives a jelly tart to a user. Accepts IDs, usernames, nicknames and mentions.']],
        group: :fun,
        aliases: [:tart]
    )

    # +hug
    command_info(
        name: :hug,
        blurb: 'Gives a hug to someone.',
        permission: :user,
        info: ['Someone in need of support, or just want to show them you care? This command sends them a warm virtual hug.'],
        usage: [['<user>', 'Sends a hug to a user. Accepts IDs, usernames, nicknames and mentions.']],
        group: :fun
    )

    # +ban
    command_info(
        name: :ban,
        blurb: '"Bans" a user',
        permission: :user,
        info: ['"Bans" a user by putting the user through a fake ban scenario.'],
        usage: [['<user>', '"Bans" the given user.']],
        group: :fun
    )
  end
end