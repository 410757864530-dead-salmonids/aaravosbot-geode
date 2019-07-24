# Migration: AddWordFilterConfigTableToDatabase
Sequel.migration do
  change do
    create_table(:word_filter_config) do
      primary_key :id
      String :message
      TrueClass :dms
      Integer :timeout
    end
  end
end