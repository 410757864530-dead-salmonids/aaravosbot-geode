# Migration: AddSoftbanUsersTableToDatabase
Sequel.migration do
  change do
    create_table(:softban_users) do
      primary_key :id
      Time :end_time
    end
  end
end