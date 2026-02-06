defmodule Jamixir.Repo.Migrations.CreateAvailability do
  use Ecto.Migration

  def change do
    create table(:availability, primary_key: false) do
      add :work_package_hash, :blob, null: false, primary_key: true
      add :shard_index, :integer, null: false
      add :bundle_length, :integer, null: false
      add :erasure_root, :blob, null: false
      add :exports_root, :blob, null: false
      add :segment_count, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:availability, [:erasure_root])
    create index(:availability, [:work_package_hash])
  end
end
