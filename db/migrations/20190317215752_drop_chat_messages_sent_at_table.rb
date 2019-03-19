# Migration: DropChatMessagesSentAtTable
Sequel.migration do
  up do
    drop_column :chat_messages, :sent_at
  end

  down do
    add_column :chat_messages, :sent_at, Time
  end
end