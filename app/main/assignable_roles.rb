# Crystal: AssignableRoles
require 'sequel'
Sequel.extension :inflector

# This crystal handles the assignable role system, in which moderators can set certain roles
# to be self-assignable by users through bot commands.
module Bot::AssignableRoles
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models
  
  include Constants

  # Master command for assignable roles
  command :roles do |event, *args|
    # Set first argument to 'info' if none were given
    args[0] ||= 'info'

    # Case first argument
    case args[0].downcase
    when 'add'
      # Break unless user is moderator and both role key and name are given
      break unless event.user.has_permission?(:moderator) &&
                   args.size >= 3

      # If an assignable role with the given key already exists, respond to user
      if AssignableRole[key: (key = args[1].downcase)]
        event << "**ERROR:** Key `#{key}` has already been assigned to a role."

      # If the key is valid and a role with the given name exists:
      elsif (role = SERVER.roles.find { |r| r.name.downcase == args[2..-1].join(' ').downcase })
        # Create assignable role
        AssignableRole.create(
            key:     args[1].downcase,
            role_id: role.id
        )

        # Respond to user
        event << "**Made role #{role.name} assignable with key `#{key}`.**"

      # If no role with the given name exists, respond to user
      else event << "**ERROR:** Role `#{args[2..-1].join(' ')}` not found."
      end

    when 'group'
      # Break unless user is moderator and both role key and name are given
      break unless event.user.has_permission?(:moderator) &&
                   args.size >= 3

      # If an assignable role with the given key exists:
      if (assignable_role = AssignableRole[key: (key = args[1].downcase)])
        role = SERVER.role(assignable_role.role_id)
        group = args[2..-1].join(' ').titleize

        # Update role entry in the database with the new group
        assignable_role.group = (group == 'None') ? 'No Group' : group

        # Save to database
        assignable_role.save

        # Respond to user
        event << "**Set group of role #{role.name} (key `#{key}`) to #{group}.**"

      # If no assignable role with the given key exists, respond to user:
      else event << "**ERROR:** Role with key `#{key}` not found."
      end

    when 'remove'
      # Break unless user is moderator and role key is given
      break unless event.user.has_permission?(:moderator) &&
                   args.size >= 2

      # If an assignable role with the given key exists:
      if (assignable_role = AssignableRole[key: (key = args[1].downcase)])
        role = SERVER.role(assignable_role.role_id)

        # Delete assignable role
        assignable_role.destroy

        # Respond to user
        event << "**Removed role #{role.name} from being assignable with key `#{key}`.**"

      # If no assignable role with the given key exists, respond to user
      else event << "**ERROR:** Role with key `#{key}` not found."
      end

    when 'desc', 'description'
      # Break unless user is moderator and role key is given
      break unless event.user.has_permission?(:moderator) &&
                   args.size >= 2
      # If a role with the given key exists in the database:
      if (assignable_role = AssignableRole[key: (key = args[1].downcase)])
        # If no description is given:
        if args.size == 2
          # Remove assignable role's description
          assignable_role.desc = nil

          # Save to database
          assignable_role.save

          # Respond to user
          event << "**Deleted description of role #{SERVER.role(assignable_role.role_id).name} (key `#{key}`).**"
        else
          desc = args[2..-1].join(' ')

          # Set assignable role's description
          assignable_role.desc = desc

          # Save to database
          assignable_role.save

          # Respond to user
          event << "**Set description of role #{SERVER.role(assignable_role.role_id).name} (key `#{key}`) to `#{desc}`.**"
        end

      # If no role with the given key exists in the database, respond to user
      else event << "**ERROR:** Role with key `#{key}` not found."
      end

    when 'info'
      groups = AssignableRole.map(:group).uniq

      event.send_embed do |embed|
        embed.author = {
            name:     'Roles: Info',
            icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.description = <<~DESC.strip
          These are the roles that you can add to yourself using their respective commands.
          If the role is in a named group, you can only have one role from that group at a time!
          To remove a role from yourself, simply use its command again.
        DESC
        groups.each do |group|
          embed.add_field(
              name:   group,
              value:  AssignableRole.where(group: group).all.map do |assignable_role|
                key = assignable_role.key
                id = assignable_role.role_id
                desc_text = assignable_role.desc ? ": #{assignable_role.desc}" : nil
                "• `+#{key}` - **#{SERVER.role(id).name}**#{desc_text}"
              end.join("\n"),
              inline: true
          )
          embed.color = 0xFFD700
          embed.footer = {text: 'This list is up to date with all assignable roles.'}
        end
      end
    end
  end

  # Detect when a user has entered the command for an assignable role
  message(start_with: '+') do |event|
    # Skip unless assignable role with given command key exists
    next unless (assignable_role = AssignableRole[key: event.message.content[1..-1].downcase])

    role = SERVER.role(assignable_role.role_id)

    # If user is removing their role:
    if event.user.role?(role)
      # Remove role and respond to user
      event.user.remove_role(role)
      event << "**#{event.user.mention}, your #{role.name} role has been removed.**"

    # If user is adding a role:
    else
      # Remove all other roles in the group from the user unless role is not in a group
      unless assignable_role.group == 'No Group'
        event.user.remove_role(AssignableRole.where(group: assignable_role.group).map(:role_id))
      end

      # Add role and respond to user
      event.user.add_role(role)
      event << "**#{event.user.mention}, you have been given the #{role.name} role.**"
    end
  end

  # Help command info
  module HelpInfo
    extend HelpCommand

    # +roles
    command_info(
        name:       :roles,
        blurb:      'Command used for self-assignable roles.',
        permission: :user,
        info: [
            'Master command for getting info on and setting up self-assignable roles.',
            'Use `+roles` to get info on how to assign yourself a role.',
            'The commands used to add, remove, group and add a description to assignable roles are exclusive to moderators.'
        ],
        usage: [
            ['info', 'Displays info on all available assignable roles and what their commands are. `+roles` with no arguments defaults to this.'],
            ['add <key> <role name>', 'Makes the role with the provided name assignable with the specified "command key". This also functions as its command.'],
            ['group <key> <role name>', 'Sets the role that has the given key to be part of the specified group. When a role is part of a group, users can only have one role of the group at a time. Set group equal to `none` to remove it from a group.'],
            ['remove <key>', 'Removes the role that has the given key from being self-assignable.'],
            ['[description/desc] <key> <description>', 'Adds a description to the role with the given key, displayed in the info command. Use without a description to delete the existing description.']
        ]
    )
  end
end