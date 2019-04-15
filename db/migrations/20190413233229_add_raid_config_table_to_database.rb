# Migration: AddRaidConfigTableToDatabase
Sequel.migration do
  change do
    create_table(:raid_config) do
      primary_key :id
      Integer :users
      Integer :seconds
    end
  end
end