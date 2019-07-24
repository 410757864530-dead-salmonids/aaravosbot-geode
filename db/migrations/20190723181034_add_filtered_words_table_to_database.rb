# Migration: AddFilteredWordsTableToDatabase
Sequel.migration do
  change do
    create_table(:filtered_words) do
      primary_key :id
      String :word
    end
  end
end