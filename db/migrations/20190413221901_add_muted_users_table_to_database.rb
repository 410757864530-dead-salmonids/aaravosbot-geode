# Migration: AddMutedUsersTableToDatabase
Sequel.migration do
  change do
    create_table(:muted_users) do
      primary_key :id
      Time :end_time
    end
  end
end