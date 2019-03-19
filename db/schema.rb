# This file contains the schema for the database.
# Under most circumstances, you shouldn't need to run this file directly.
require 'sequel'

module Schema
  Sequel.sqlite(ENV['DB_PATH']) do |db|
    db.create_table?(:chat_users) do
      primary_key :id
      Integer :channel_id
      DateTime :start_time
    end

    db.create_table?(:chat_messages) do
      primary_key :id
      String :message, :size=>255
      foreign_key :chat_user_id, :chat_users
    end

    db.create_table?(:assignable_roles) do
      primary_key :id
      String :key, :size=>255
      Integer :role_id
      String :group, :default=>"No Group", :size=>255
      String :desc, :size=>255
    end
  end
end