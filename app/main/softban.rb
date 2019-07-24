# Crystal: Softban


# TODO Write what the crystal does here.
module Bot::Softban
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models

  extend Convenience
  include Constants

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

  # Schedule Rufus jobs to unban all softbanned users at the end of their bans
  ready do
    SoftbanUser.all do |softban_user|
      SCHEDULER.at softban_user.end_time do
        # Unban user and delete from database
        SERVER.unban(softban_user.id, 'Softban expiry')
        softban_user.destroy
      end
    end
  end

  command [:softban, :tempban] do |event, *args|
    # Break unless user is moderator, given user is valid, not staff or already softbanned
    break unless event.user.has_permission?(:moderator) &&
                 (user = SERVER.get_user(args.join(' '))) &&
                 !user.has_permission?(:moderator)
                 !SoftbanUser[user.id]

    msgs = Array.new

    # Prompt user for the length of the ban
    msg = event.respond "**How long should the ban last?** Press ❌ to cancel."
    msg.react('❌')
    msgs.push(msg)

    # Await length of time
    time = nil
    Thread.new do
      time = loop do
        await_event = event.message.await!
        break if time
        msgs.push(await_event.message)
        break parse_time(await_event.message.content) if parse_time(await_event.message.content) >= 10
        event.send_temp("That's not a valid length of time.", 5)
      end
    end
    Thread.new do
      time = loop do
        await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '❌')
        break :cancel if await_event.user == event.user
      end
    end
    sleep 0.05 until time

    # Delete messages and respond to user if user canceled ban
    if time == :cancel
      msgs.each { |m| m.delete }
      break '**Canceled softban.**'
    end

    # Prompt user for number of days of messages to be deleted with ban
    msg = event.respond '**How many days of messages should be deleted?**'
    msgs.push(msg)

    # Await user response
    await_event = event.message.await!
    msgs.push(await_event.message)
    ban_days = await_event.message.content.to_i

    # Prompt user for ban reason
    msg = event.respond '**Would you like to input a reason for the softban?** Press 🔨 if not, otherwise reply with the reason.'
    msg.react('🔨')
    msgs.push(msg)

    # Await user response
    reason_text = nil
    reason = nil
    Thread.new do
      reason_text = loop do
        await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '🔨')
        break '' if await_event.user == event.user
      end
    end
    Thread.new do
      await_event = event.message.await!
      msgs.push(await_event.message)
      reason = await_event.message.content
    end
    sleep 0.05 until reason

    reason_text = "\n**Reason:** #{reason}"
    shortened_reason = reason.length > 512 ? (reason[0..508] + '...' : reason)

    end_time = Time.now + time
    softban_user = SoftbanUser.create(
        id:       user.id,
        end_time: end_time
    )

    # Delete all messages in array
    msgs.each { |m| m.delete }

    # Send log embed to #mod_log
    Bot::BOT.channel(MOD_LOG_ID).send_embed do |embed|
      embed.author = {
          name: "SOFTBAN | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = <<~DESC.strip
        🔨 **#{user.mention} was banned for #{time_string(time)}.**#{reason_text}
        
        **Banned by:** #{event.user.mention} (#{event.user.distinct})
      DESC
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end

    # DM message to user
    user.pm "**#{user.mention}, you've been banned for #{time_string(time)}.**#{reason_text}"

    # Ban user
    SERVER.ban(
        user, ban_days,
        reason: shortened_reason
    )

    # Schedule Rufus job to unban user
    SCHEDULER.at end_time do
      # Unban user and delete from database
      SERVER.unban(user, 'Softban expiry')
      softban_user.destroy
    end

    # Respond to user
    event << "**Softbanned #{user.distinct}.**"
  end
end