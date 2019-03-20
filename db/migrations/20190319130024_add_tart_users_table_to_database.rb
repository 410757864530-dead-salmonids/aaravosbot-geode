# Migration: AddTartUsersTableToDatabase
Sequel.migration do
  change do
    create_table(:tart_users) do
      primary_key :id
      Integer :given, default: 0
      Integer :received, default: 0
    end
  end
end