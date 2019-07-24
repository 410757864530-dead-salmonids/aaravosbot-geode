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

    db.create_table?(:tart_users) do
      primary_key :id
      Integer :given, :default=>0
      Integer :received, :default=>0
    end

    db.create_table?(:hug_users) do
      primary_key :id
      Integer :given, :default=>0
      Integer :received, :default=>0
    end

    db.create_table?(:muted_users) do
      primary_key :id
      DateTime :end_time
    end

    db.create_table?(:raid_config) do
      primary_key :id
      Integer :users
      Integer :seconds
    end

    db.create_table?(:flood_config) do
      primary_key :id
      Integer :messages
      Integer :seconds
    end

    db.create_table?(:quoted_messages) do
      primary_key :id
      Integer :channel_id
    end

    db.create_table?(:quotes_config) do
      primary_key :id
      Integer :cameras
    end

    db.create_table?(:softban_users) do
      primary_key :id
      DateTime :end_time
    end

    db.create_table?(:filtered_words) do
      primary_key :id
      String :word, :size=>255
    end

    db.create_table?(:word_filter_config) do
      primary_key :id
      String :message, :size=>255
      TrueClass :dms
      Integer :timeout
    end
  end
end