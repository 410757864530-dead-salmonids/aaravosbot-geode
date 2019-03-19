# Migration: AddChatUsersTableToDatabase
Sequel.migration do
  change do
    create_table(:chat_users) do
      primary_key :id
      Integer :channel_id
      Time :start_time
    end
  end
end