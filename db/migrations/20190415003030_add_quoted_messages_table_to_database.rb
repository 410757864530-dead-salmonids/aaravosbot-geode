# Migration: AddQuotedMessagesTableToDatabase
Sequel.migration do
  change do
    create_table(:quoted_messages) do
      primary_key :id
    end
  end
end