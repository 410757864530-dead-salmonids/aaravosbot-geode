# Migration: AddChatMessagesTableToDatabase
Sequel.migration do
  change do
    create_table(:chat_messages) do
      primary_key :id
      String :message
      Time :sent_at
      foreign_key :chat_user_id, :chat_users
    end
  end
end