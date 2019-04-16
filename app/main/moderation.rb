# Crystal: Moderation


# Manages the moderation features of the bot.
module Bot::Moderation
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models

  extend Convenience
  include Constants

  # Muted channel ID
  MUTED_CHANNEL_ID = 541809796911726602
  # #mod_log ID
  MOD_LOG_ID = 545113155831988235

  module_function

  # Takes the given time string argument, in a format similar to '5d2h15m45s' and returns its representation in
  # a number of seconds.
  # @param  [String]  str the string to parse into a number of seconds
  # @return [Integer]     the number of seconds the given string is equal to, or 0 if it cannot be parsed properly
  def parse_time(str)
    seconds = 0
    str.scan(/\d+ *[Dd]/).each { |m| seconds += (m.to_i * 24 * 60 * 60) }
    str.scan(/\d+ *[Hh]/).each { |m| seconds += (m.to_i * 60 * 60) }
    str.scan(/\d+ *[Mm]/).each { |m| seconds += (m.to_i * 60) }
    str.scan(/\d+ *[Ss]/).each { |m| seconds += (m.to_i) }
    seconds
  end

  # Takes the given number of seconds and converts into a string that describes its length (i.e. 3 hours,
  # 4 minutes and 5 seconds, etc.)
  # @param  [Integer] secs the number of seconds to convert
  # @return [String]       the length of time described
  def time_string(secs)
    dhms = ([secs / 86400] + Time.at(secs).utc.strftime('%H|%M|%S').split("|").map(&:to_i)).zip(['day', 'hour', 'minute', 'second'])
    dhms.shift while dhms[0][0] == 0
    dhms.pop while dhms[-1][0] == 0
    dhms.map! { |(v, s)| "#{v} #{s}#{v == 1 ? nil : 's'}" }
    return dhms[0] if dhms.size == 1
    "#{dhms[0..-2].join(', ')} and #{dhms[-1]}"
  end

  raid_bucket = Bot::BOT.bucket(
      :raid,
      limit: RaidConfig.instance.users - 1,
      time_span: RaidConfig.instance.seconds
  )
  flood_bucket = Bot::BOT.bucket(
      :flood,
      limit: FloodConfig.instance.messages - 1,
      time_span: FloodConfig.instance.seconds
  )
  raid_mode_active = false
  raid_users = Array.new
  mute_jobs = Hash.new

  # Schedule unmute jobs for every user currently muted upon starting the bot
  ready do
    # Iterate through all muted users
    MutedUser.all do |muted_user|
      # Schedule Rufus job at the end time of the mute and store its ID in the job hash
      mute_jobs[muted_user.id] = SCHEDULER.at muted_user.end_time do
        # Unmute the user, catching and logging any exceptions in case issues arise
        begin
          SERVER.member(muted_user.id).modify_roles(
              MEMBER_ID, # adds Member
              MUTED_ID   # removes Muted
          )
        rescue StandardError
          puts 'Exception raised when unmuting user -- likely user left server'
        end

        # Delete user entry from job hash and database
        mute_jobs.delete(muted_user.id)
        muted_user.destroy
      end
    end
  end

  # Re-mute user if they leave the server and rejoin during their mute
  member_join do |event|
    # Skip unless user is muted
    next unless MutedUser[event.user.id]

    # Short delay before modifying roles to allow Mee6 to give user the member role;
    # otherwise user will have the role added before Aaravos is able to remove it
    sleep 3
    event.user.modify_roles(
        MUTED_ID, # adds Muted
        MEMBER_ID # removes Member
    )
  end

  # Send warning to user
  command :warn, aliases: [:warning] do |event, *args|
    # Break unless user is moderator and given user is valid
    break unless event.user.has_permission?(:moderator) &&
                 (user = SERVER.get_user(args.join(' ')))

    msgs = Array.new

    # Prompt user for warning message
    msg = event.respond '**What should the warning message be?** Press ❌ to cancel.'
    msg.react('❌')
    msgs.push(msg)

    # Await user response
    reason = nil
    Thread.new do
      reason = loop do
        await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '❌')
        break :cancel if await_event.user == event.user
      end
    end
    Thread.new do
      await_event = event.message.await!
      msgs.push(await_event.message)
      reason = await_event.message.content
    end
    sleep 0.05 until reason

    # Delete all temporary messages
    msgs.each { |m| m.delete }

    # Break command and respond to user if user canceled warning
    break '**Canceled warning.**' if reason == :cancel

    # Send log embed to #mod_log
    Bot::BOT.channel(MOD_LOG_ID).send_embed do |embed|
      embed.author = {
          name: "WARNING | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = <<~DESC.strip
        ⚠ **#{user.mention} was issued a warning by #{event.user.mention}.**
        **Reason:** #{reason}
        
        **Issued by:** #{event.user.mention} (#{event.user.distinct})
      DESC
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end

    # DM warning message to user
    user.dm <<~DM.strip
      **You've recieved a warning from one of the staff members.**
      **Reason:** #{reason}
    DM

    # Respond to command
    event << "**Sent warning to #{user.distinct}.**"
  end

  # Mute user
  command :mute do |event, *args|
    # Break unless user is moderator and given user is valid
    break unless event.user.has_permission?(:moderator) &&
                 (user = SERVER.get_user(args.join(' ')))

    msgs = Array.new

    # Prompt user for the length of time for the mute
    msg = event.respond '**How long should the mute last?** Press ❌ to cancel.'
    msg.react('❌')
    msgs.push(msg)

    # Await user response
    mute_response = nil
    Thread.new do
      mute_response = loop do
        await_event = event.message.await!
        break if mute_response
        msgs.push(await_event.message)
        break await_event.message.content if parse_time(await_event.message.content) >= 10
        event.send_temp(
            "That's not a valid length of time.",
            5 # seconds to delete
        )
      end
    end
    Thread.new do
      mute_response = loop do
        await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '❌')
        break :cancel if await_event.user == event.user
      end
    end
    sleep 0.05 until mute_response

    # Delete all messages in array, break command and respond if user canceled mute
    if mute_response == :cancel
      msgs.each { |m| m.delete }
      break '**Canceled mute.**'
    end

    # Prompt user whether they would like to input a reason
    msg = event.respond '**Would you like to input a reason for the mute?** Press 🔇 if not, otherwise reply with the reason.'
    msg.react('🔇')
    msgs.push(msg)

    # Await user response
    reason_text = nil
    Thread.new do
      reason_text = loop do
        await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '🔇')
        break '' if await_event.user == event.user
      end
    end
    Thread.new do
      await_event = event.message.await!
      msgs.push(await_event.message)
      reason_text = "\n**Reason:** #{await_event.message.content}"
    end
    sleep 0.05 until reason_text

    muted_user = MutedUser[user.id] || MutedUser.create(id: user.id)
    mute_length = parse_time(mute_response)
    end_time = Time.now + mute_length

    # Delete all messages in array
    msgs.each { |m| m.delete }

    # Unschedule previous Rufus job, if any existed
    SCHEDULER.job(mute_jobs[user.id]).unschedule if mute_jobs[user.id]

    # Mute user, add them to mute database and save
    user.modify_roles(
        MUTED_ID,
        MEMBER_ID
    )
    muted_user.end_time = end_time
    muted_user.save

    # Schedule Rufus job to unmute user
    mute_jobs[user.id] = SCHEDULER.at end_time do
      # Unmute user
      begin
        user.modify_roles(
            MEMBER_ID,
            MUTED_ID
        )
      rescue StandardError
        puts 'Exception raised when unmuting user -- likely user left server'
      end

      # Delete user entry from job hash and database
      mute_jobs.delete(user.id)
      muted_user.destroy
    end

    # Send log embed to #mod_log
    Bot::BOT.channel(MOD_LOG_ID).send_embed do |embed|
      embed.author = {
          name: "MUTE | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = <<~DESC.strip
        🔇 **#{user.mention} was muted for #{time_string(mute_length)}.**#{reason_text}
        
        **Muted by:** #{event.user.mention} (#{event.user.distinct})
      DESC
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end

    # Send message in #muted_channel
    Bot::BOT.send_message(
        MUTED_CHANNEL_ID,
        "**#{user.mention}, you've been muted for #{time_string(mute_length)}.**#{reason_text}"
    )

    # Respond to user
    event << "**Muted #{user.distinct}.**"
  end

  # Unmute user
  command :unmute do |event, *args|
    # Break unless user is moderator, given user is valid and is currently muted
    break unless event.user.has_permission?(:moderator) &&
        (user = SERVER.get_user(args.join(' '))) &&
        (muted_user = MutedUser[user.id])

    # Unmute user, unschedule Rufus job and delete user from database
    user.modify_roles(
        MEMBER_ID, # adds Member
        MUTED_ID   # removes Muted
    )
    SCHEDULER.job(mute_jobs[user.id]).unschedule
    mute_jobs.delete(user.id)
    muted_user.destroy

    # Respond to user
    event << "**Unmuted #{user.distinct}.**"
  end

  # Kick user
  command :kick do |event, *args|
    # Break unless user is moderator and given user is valid
    break unless event.user.has_permission?(:moderator) &&
                 (user = SERVER.get_user(args.join(' ')))

    msgs = Array.new

    # Prompt user for the length of time for the mute
    msg = event.respond <<~RESPONSE.strip
      **What is the reason for the kick?** A reason must be given.
      Press ❌ to cancel.
    RESPONSE
    msg.react('❌')
    msgs.push(msg)

    # Await user response
    reason = nil
    Thread.new do
      reason = loop do
        await_event = event.message.await!
        msgs.push(await_event.message)
        reason = await_event.message.content
      end
    end
    Thread.new do
      reason = loop do
        await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '❌')
        break :cancel if await_event.user == event.user
      end
    end
    sleep 0.05 until reason

    # Delete all messages in array
    msgs.each { |m| m.delete }

    # Break command and respond if user canceled kick
    break '**Canceled kick.**' if reason == :cancel

    # Send log embed to #mod_log
    Bot::BOT.channel(MOD_LOG_ID).send_embed do |embed|
      embed.author = {
          name:     "KICK | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = <<~DESC.strip
        👢 **#{user.mention} was kicked.**
        **Reason:** #{reason}
        
        **Kicked by:** #{event.user.mention} (#{event.user.distinct})
      DESC
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end

    # Kick user
    SERVER.kick(user, reason)

    # Respond to user
    event << "**Kicked #{user.distinct}.**"
  end

  # Ban user
  command :ban do |event, *args|
    # Break unless user is moderator and given user is valid
    break unless event.user.has_permission?(:moderator) &&
                 (user = SERVER.get_user(args.join(' ')))

    msgs = Array.new

    # Prompt user for the number of days of messages that should be deleted
    msg = event.respond '**How many days of messages should be deleted?** Press ❌ to cancel.'
    msg.react('❌')
    msgs.push(msg)

    # Await user response
    ban_days = nil
    Thread.new do
      ban_days = loop do
        await_event = event.message.await!
        break if ban_days
        msgs.push(await_event.message)
        break await_event.message.content.to_i
      end
    end
    Thread.new do
      ban_days = loop do
        await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '❌')
        break :cancel if await_event.user == event.user
      end
    end
    sleep 0.05 until ban_days

    # Delete all messages in array, break command and respond if user canceled ban
    if ban_days == :cancel
      msgs.each { |m| m.delete }
      break '**Canceled ban.**'
    end

    # Prompt user for reason
    msg = event.respond '**What is the reason for the ban?** A reason must be given.'
    msgs.push(msg)

    # Await user response
    await_event = event.message.await!
    msgs.push(await_event.message)
    reason = await_event.message.content

    # Delete all messages in array
    msgs.each { |m| m.delete }

    # Send log embed to #mod_log
    Bot::BOT.channel(MOD_LOG_ID).send_embed do |embed|
      embed.author = {
          name:     "BAN | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = <<~DESC.strip
        🔨 **#{user.mention} was banned** with #{pl(ban_days, 'days')} of messages deleted.
        **Reason:** #{reason}
        
        **Issued by:** #{event.user.mention} (#{event.user.distinct})
      DESC
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end

    # Delete user's mute entry from job hash and database if it exists
    mute_jobs.delete(user.id)
    MutedUser[user.id].destroy if MutedUser[user.id]

    # Ban user
    SERVER.ban(user, ban_days, reason: reason)

    # Respond to user
    event << "**Banned #{user.distinct}.**"
  end

  # Purge messages in channel
  command :purge do |event, *args|
    # Break unless user is a moderator, the number of messages to scan is given and is between 1 and 100
    break unless event.user.has_permission?(:moderator) &&
                 args.size >= 1 &&
                 (1..100).include?(count = args[0].to_i)

    # Delete event message
    event.message.delete

    # If no extra arguments were given, retrieve the given number of messages in this channel's history
    if args.size == 1
      messages_to_delete = event.channel.history(args[0].to_i)

    # If arguments begin and end with quotation marks, scan the given number of messages in this
    # channel's history and select the ones containing the text within the quotation marks
    elsif args.size > 1 &&
          args[1..-1].join(' ')[0] == "\"" &&
          args[1..-1].join(' ')[-1] == "\""
      text = args[1..-1].join(' ')[1..-2]
      messages_to_delete = event.channel.history(args[0].to_i).select { |m| m.content.downcase.include?(text.downcase) }

    # If the arguments represent a valid user, scan the given number of messages in this
    # channel's history and select the ones from the user
    elsif args.size > 1 &&
          (user = SERVER.get_user(args[1..-1].join(' ')))
      messages_to_delete = event.channel.history(args[0].to_i).select { |m| user && m.author.id == user.id }

      # Otherwise, respond to command
    else event.send_temp('Invalid arguments.', 5)
    end

    # If no messages with the given parameters were found to purge, respond to user
    if (messages_found = messages_to_delete.size) == 0
      event.send_temp('No messages were found to purge.', 5)

    # Otherwise, delete the selected messages and respond to user
    else
      if messages_found == 1
        messages_to_delete[0].delete
      else event.channel.delete_messages(messages_to_delete)
      end
      message_text = if text
                       "Searched **#{pl(count, 'messages')}** and deleted **#{messages_found}** containing the text `#{text}`."
                     elsif user
                       "Searched **#{pl(count, 'messages')}** and deleted **#{messages_found}** from user `#{user.distinct}`."
                     else "Deleted **#{pl(messages_found, 'messages')}**."
                     end
      event.send_temp(message_text, 5)
    end
  end

  # Raid protection functionality upon member joining
  member_join do |event|
    # If raid mode is active when the user joins:
    if raid_mode_active
      # Short delay to allow Mee6 to give user the member role; otherwise user will have the role
      # added before Aaravos is able to remove it
      sleep 3

      # Mute user and add to tracker
      event.user.on(SERVER).modify_roles(MUTED_ID, MEMBER_ID)
      raid_users.push(event.user)

    # Otherwise, activate raid mode and send message to #mod_log if the rate limit has triggered
    else
      if raid_bucket.rate_limited?(:join)
        raid_mode_active = true
        raid_bucket.reset(:join)
        Bot::BOT.send_message(MOD_LOG_ID, '@here **Raid protections have been activated.** New joins will be muted.')
      end
    end
  end

  # Disables raid mode
  command :unraid do |event|
    # Breaks unless user is moderator and raid mode is active
    break unless event.user.has_permission?(:moderator) &&
                 raid_mode_active

    # Unmute all tracked users if still present on server
    raid_users.each do |user|
      event.user.on(SERVER).modify_roles(MEMBER_ID, MUTED_ID) if SERVER.member(user.id)
    end

    # Clear tracked users
    raid_users = Array.new

    # Disable raid mode and responds to user
    raid_mode_active = false
    event << '**Raid protections deactivated.**'
  end

  # Check and set the config options for raid mode
  command :raidconfig do |event, *args|
    # Break unless user is moderator
    break unless event.user.has_permission?(:moderator)

    # Set default argument to check
    args[0] ||= 'check'

    config = RaidConfig.instance

    # If user wants to check the current config, send embed containing the info
    if args[0].downcase == 'check'
      event.send_embed do |embed|
        embed.author = {
            name: 'Raid: Current Configuration',
            icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.description = <<~DESC.strip
          **Users:** #{config.users}
          **Seconds:** #{config.seconds}
          *(If #{pl(config.users, 'users')} join in #{pl(config.seconds, 'seconds')}, raid mode activates.)*
        DESC
        embed.footer = {text: 'To change the config options, use `+raidconfig set [option]`.'}
        embed.color = 0xFFD700
      end

    # If user wants to change a config option and necessary arguments are given:
    elsif args[0].downcase == 'set' &&
          args.size == 3
      # If user wants to set the number of user joins and the number is valid:
      if args[1].downcase == 'users' &&
         (value = args[2].to_i) > 0
        # Update the data in the config and save to database
        config.users = value
        config.save

        # Overwrite existing raid bucket with new settings
        raid_bucket = Bot::BOT.bucket(
            :raid,
            limit: value - 1,
            time_span: config.seconds
        )

        # Respond to user
        event << "**Set the user joins needed to trigger raid mode to #{value}.**"

      # If user wants to set the time span and the number is valid:
      elsif args[1].downcase == 'seconds' &&
            (value = args[2].to_i) > 0
        # Update the data in the config and save to database
        config.seconds = value
        config.save

        # Overwrite existing raid bucket with new settings
        raid_bucket = Bot::BOT.bucket(
            :raid,
            limit: config.users,
            time_span: value
        )

        # Respond to user
        event << "**Set the time span in which enough user joins will trigger raid mode to #{pl(value, 'seconds')}.**"
      end
    end
  end

  # Flood protection
  message do |event|
    # Skip unless a user has triggered the flood bucket
    next unless flood_bucket.rate_limited?(event.user.id)

    # Reset flood bucket for user
    flood_bucket.reset(event.user.id)

    # Delete the user's message history in the event channel
    user_messages = event.channel.history(50).select { |m| m.author == event.user }[0..(FloodConfig.instance.messages)]
    event.channel.delete_messages(user_messages)
  end


  # Check and set the config options for message flood deletion
  command :floodconfig do |event, *args|
    # Break unless user is moderator
    break unless event.user.has_permission?(:moderator)

    # Set default argument to check
    args[0] ||= 'check'

    config = FloodConfig.instance

    # If user wants to check the current config, send embed containing the info
    if args[0].downcase == 'check'
      event.send_embed do |embed|
        embed.author = {
            name: 'Flood: Current Configuration',
            icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.description = <<~DESC.strip
          **Messages:** #{config.messages}
          **Seconds:** #{config.seconds}
          *(If a user sends #{pl(config.messages, 'messages')} in #{pl(config.seconds, 'seconds')}, they are automatically deleted.)*
        DESC
        embed.footer = {text: 'To change the config options, use `+floodconfig set [option]`.'}
        embed.color = 0xFFD700
      end

    # If user wants to change a config option and necessary arguments are given:
    elsif args[0].downcase == 'set' &&
          args.size == 3
      # If user wants to set the number of messages and the number is valid:
      if args[1].downcase == 'messages' &&
         (value = args[2].to_i) > 0
        # Update the data in the config and save to database
        config.messages = value
        config.save

        # Overwrite existing flood bucket with new settings
        flood_bucket = Bot::BOT.bucket(
            :flood,
            limit: value - 1,
            time_span: config.seconds
        )

        # Respond to user
        event << "**Set the max messages to be sent within the defined time span to #{value}.**"

        # If user wants to set the time span and the number is valid:
      elsif args[1].downcase == 'seconds' &&
            (value = args[2].to_i) > 0
        # Update the data in the config and save to database
        config.seconds = value
        config.save

        # Overwrite existing flood bucket with new settings
        flood_bucket = Bot::BOT.bucket(
            :flood,
            limit: config.messages,
            time_span: value
        )

        # Respond to user
        event << "**Set the time span in which enough messages will trigger deletion to #{value} seconds.**"
      end
    end
  end

  # Help command info
  module HelpInfo
    extend HelpCommand

    # +warn
    command_info(
        name: :warn,
        blurb: 'Sends a warning to a user.',
        permission: :moderator,
        info: [
            'Sends a warning to a user by DM. If a valid user is given, Aaravos will prompt for the reason.',
            'Can be canceled by pressing the X button.'
        ],
        usage: [['<user>', 'Sends a warning to the given user. Accepts IDs, mentions, nicknames and full usernames.']],
        group: :moderation,
        aliases: [:warning]
    )

    # +mute
    command_info(
        name: :mute,
        blurb: 'Mutes a user.',
        permission: :moderator,
        info: [
            'Mutes a user. If a valid user is given, Aaravos will prompt for the mute time, followed by an optional reason.',
            'Can be canceled by pressing the X button when being prompted for the mute time.'
        ],
        usage: [['<user>', 'Mutes the given user. Accepts IDs, mentions, nicknames and full usernames.']],
        group: :moderation
    )

    # +unmute
    command_info(
        name: :unmute,
        blurb: 'Unmutes a user.',
        permission: :moderator,
        info: [
            'Unmutes a user.',
            "Not much else to it -- it's pretty self-explanatory."
        ],
        usage: [['<user>', 'Unmutes the given user. Accepts IDs, mentions, nicknames and full usernames.']],
        group: :moderation
    )

    # +kick
    command_info(
        name: :kick,
        blurb: 'Kicks a user.',
        permission: :moderator,
        info: [
            'Kicks a user. If a valid user is given, Aaravos will prompt for the reason.',
            'Can be canceled by pressing the X button when being prompted for the reason.'
        ],
        usage: [['<user>', 'Kicks the given user. Accepts IDs, mentions, nicknames and full usernames.']],
        group: :moderation
    )

    # +ban
    command_info(
        name: :ban,
        blurb: 'Bans a user.',
        permission: :moderator,
        info: [
            'Ban a user. If a valid user is given, Aaravos will prompt for the number of days of messages to be deleted, followed by the reason.',
            'Can be canceled by pressing the X button when being prompted for the number of days.'
        ],
        usage: [['<user>', 'Bans the given user. Accepts IDs, mentions, nicknames and full usernames.']],
        group: :moderation
    )

    # +purge
    command_info(
        name: :purge,
        blurb: 'Deletes a number of messages from a channel.',
        permission: :moderator,
        group: :moderation,
        info: [
            'Deletes a given number of the most recent messages in the channel it is used in.',
            'Optionally can be given a user or text input, and the bot will scan through the given number of messages and delete any made by that user or contain that text.'
        ],
        usage: [
            ['<number>', 'Deletes the given number of the most recent messages.'],
            ['<number> <user>', 'Scans through the given number of messages and deletes any from the given user. Accepts user ID, mention, username (with or without discrim) or nickname.'],
            ['<number> "text"', 'Scans through the given number of messages and deletes any containing the given text. Make sure to include quotation marks!']
        ]
    )

    # +unraid
    command_info(
        name: :unraid,
        blurb: 'Disables raid mode.',
        permission: :moderator,
        info: [
            'Disables raid mode if it is currently active.',
            'New users will no longer be automatically muted upon joining.'
        ],
        group: :moderation
    )

    # +raidconfig
    command_info(
        name: :raidconfig,
        blurb: 'Used to manage configuration for raid protection.',
        permission: :moderator,
        info: [
            'Allows user to manage raid protection configuration (checking or changing settings).',
            'The options that can be set are the limit on the users that can join in a number of seconds, and that time period itself.'
        ],
        usage: [
            ['check', 'Returns what the current configuration is. This is the default for no arguments.'],
            ['set users <number>', 'Sets the limit of users that can join in the given time span.'],
            ['set seconds <number>', 'Sets the time span within which joins should be limited, in seconds.']
        ],
        group: :moderation
    )

    # +floodconfig
    command_info(
        name: :floodconfig,
        blurb: 'Used to manage configuration for message flood protection.',
        permission: :moderator,
        info: [
            'Allows user to manage message flood protection configuration (checking or changing settings).',
            'The options that can be set are the limit on the messages that can be sent by a user in a given time, and that time period itself.'
        ],
        usage: [
            ['check', 'Returns what the current configuration is. This is the default for no arguments.'],
            ['set messages <number>', 'Sets the limit of messages that can be sent in the given time span.'],
            ['set seconds <number>', 'Sets the time span within which messages should be limited, in seconds.']
        ],
        group: :moderation
    )
  end
end