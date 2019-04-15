# Migration: AddChannelIdToQuotedMessages
Sequel.migration do
  change do
    alter_table :quoted_messages do
      add_column :channel_id, Integer
    end
  end
end