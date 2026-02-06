defmodule Jamixir.Repo.Migrations.CreateAssurances do
  use Ecto.Migration

  def change do
    create table(:assurances, primary_key: false) do
      add :hash, :blob, null: false, primary_key: true
      add :validator_index, :integer, null: false, primary_key: true
      add :bitfield, :blob, null: false
      add :signature, :blob, null: false

      timestamps(type: :utc_datetime)
    end

    # Additional indexes if needed for queries
    create index(:assurances, [:validator_index])
    create index(:assurances, [:inserted_at])
  end
end
