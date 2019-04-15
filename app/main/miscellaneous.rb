# Crystal: Miscellaneous


# Contains miscellaneous features that don't fit well into other crystals.
module Bot::Miscellaneous
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models

  include Constants

  # AaravosMusic ID
  AARAVOS_MUSIC_ID = 509544850085904384
  # #dragon-dj channel ID
  DRAGON_DJ_ID = 492864853401141259

  # Detect when a user has joined, moved or left a voice channel, and update
  # voice text channel visibility accordingly
  voice_state_update do |event|
    # Skip if user is AaravosMusic or event channel is the same as old channel
    # (user is just changing their mute/deafen state)
    next if event.user.id == AARAVOS_MUSIC_ID ||
            event.channel == event.old_channel

    voice_text_chats = YAML.load_data! "#{ENV['DATA_PATH']}/voice_text_chats.yml"

    # Delete user's overwrites in each of the voice text channels
    voice_text_chats.each_value { |id| Bot::BOT.channel(id).delete_overwrite(event.user.id) }

    # If user has joined a voice channel that has a corresponding text channel, define
    # overwrite for its text channel and respond to user
    if event.channel && voice_text_chats[event.channel.id]
      text_channel = Bot::BOT.channel(voice_test_chats[event.channel.id])
      text_channel.define_overwrite(event.user, 1024, 0)
      text_channel.send_temporary_message(
          <<~MESSAGE.strip,
            **#{event.user.mention}, welcome to #{text_channel.mention}.**
            This is the text chat for the voice channel you're connected to.
          MESSAGE
          10 # seconds to delete
      )
    end
  end

  # Clean command for #dragon-dj channel; not indexed in +help because it is technically part of music module
  command(:clean, channels: [DRAGON_DJ_ID]) do |event, arg = '40'|
    # Breaks unless the given number of messages is within 2 and 100
    break unless (2..100).include?(arg.to_i)

    messages = event.channel.history(arg.to_i).select { |m| m.author.id == AARAVOS_MUSIC_ID || m.content[0] == '+' }

    # Cases the message count, as the Channel#delete_messages method does not support deletion of a single message
    case messages.size
    when 2..100 then event.channel.delete_messages(messages)
    when 1 then messages[0].delete
    end

    # Responds to user
    event.send_temp(
        "Searched **#{arg.to_i}** messages and cleaned up **#{messages.size}** music commands and responses.",
        5 # seconds to delete
    )
  end
end