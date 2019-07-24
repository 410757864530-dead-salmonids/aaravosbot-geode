# Crystal: WordFilter


# TODO Write what the crystal does here.
module Bot::WordFilter
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models

  extend Convenience
  include Constants

  # Delete message containing a filtered word
  message do |event|
    # Skip unless message contains a filtered word and is not from moderator/bot
    next unless (filtered_word = FilteredWord.map(:word).find { |w| event.message.content.downcase.include?(w) }) &&
                !event.user.has_permission?(:moderator) &&
                event.user.id != Bot::BOT.profile.id

    # Delete message
    event.message.delete

    config = WordFilterConfig.instance
    message = config.message.gsub('{word}', filtered_word)

    # If DM config option is on, DM user warning
    if config.dms
      event.user.dm message

    # If message timeout is greater than 0, reply with temporary message in event channel with given timeout
    elsif config.timeout > 0
      event.send_temp(message, config.timeout)

    # Otherwise, respond with permanent message in event channel
    else
      event.respond message
    end
  end

  # Add, remove or list filtered words
  command :filter do |event, *args|
    # Set argument to list if no arguments are given
    args[0] ||= 'list'

    # Break unless user is moderator
    break unless event.user.has_permission?(:moderator)

    # If user is adding word to filter, create entry in database and respond to user
    if args[0] == 'add' &&
       args.size >= 2
      filtered_word = FilteredWord.create(word: args[1..-1].join(' '))
      event << "**Added `#{filtered_word.word}` to filter.**"

    # If user is removing word from filter, remove entry from database and respond to user
    elsif args[0] == 'remove' &&
          args.size >= 2 &&
          (filtered_word = FilteredWord[word: args[1..-1].join(' ')])
      filtered_word.destroy
      event << "**Removed `filtered_word.word` from filter.**"

    # If user is listing all filtered words, respond with embed
    elsif args[0] == 'list'
      event.send_embed do |embed|
        embed.author = {
            name:     'Filter: All Filtered Words',
            icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.description = FilteredWord.map([:id, :word]).map { |id, w| "**#{id}.** `#{w}`" }.join("\n")
        embed.footer = {text: 'Use +filter to add/remove/list filtered words.'}
        embed.color = 0xFFD700
      end
    end
  end

  # Manage filter config
  command :filterconfig do |event, *args|
    # Break unless user is moderator
    break unless event.user.has_permission?(:moderator)

    config = WordFilterConfig.instance

    # If no arguments are given, show current config
    if args.empty?
      event.send_embed do |embed|
        embed.author = {
            name:     'Filter: Current Configuration',
            icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.description = <<~DESC.strip
          **Message:** `#{config.message}`
          **Warning Location:** #{config.dms ? 'DMs' : 'Channel it happened in'}
          **Message Timeout:** #{config.timeout} seconds
        DESC
        embed.footer = {text: 'To display the word in the warning message, '}
        embed.color = 0xFFD700
      end

    elsif args[0] == 'message' &&
          args.size >= 2
      config.message = args[1..-1].join(' ')
      config.save
      event << "**Changed warning message to `config.message`.**"

    elsif args[0] == 'location' &&
          args.size >= 2
      case args[1]
      when 'dms', 'dm', 'pms', 'pm'
        config.dms = true
        config.save
        event << '**Set warning location to DMs.**'
      when 'channel'
        config.dms = false
        config.save
        if config.timeout == 0
          event << '**Set warning location to channel it happened in.** Warning will not disappear.'
        else
          event << "**Set warning location to channel it happened in.** Warning will disappear after `#{config.timeout}` seconds."
        end
      end

    elsif args[0] == 'timeout' &&
          args.size == 2 &&
          (timeout = args[1].to_i) >= 0
      config.timeout = timeout
      config.save
      if timeout == 0
        event << '**Turned off timeout for warning.**'
      else
        event << "**Warning will disappear after `#{timeout}` seconds.**"
      end
    end
  end
end