# Migration: AddFloodConfigTableToDatabase
Sequel.migration do
  change do
    create_table(:flood_config) do
      primary_key :id
      Integer :messages
      Integer :seconds
    end
  end
end