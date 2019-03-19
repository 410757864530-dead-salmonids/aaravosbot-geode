# Migration: AddAssignableRolesTableToDatabase
Sequel.migration do
  change do
    create_table(:assignable_roles) do
      primary_key :id
      String :key
      Integer :role_id
      String :group, default: 'No Group'
      String :desc
    end
  end
end