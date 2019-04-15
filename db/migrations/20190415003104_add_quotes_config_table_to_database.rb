# Migration: AddQuotesConfigTableToDatabase
Sequel.migration do
  change do
    create_table(:quotes_config) do
      primary_key :id
      Integer :cameras
    end
  end
end