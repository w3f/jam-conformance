defmodule Jamixir.Repo.Migrations.CreatePreimagesMetadata do
  use Ecto.Migration

  def change do
    create table(:preimage_metadata, primary_key: false) do
      add :hash, :blob, null: false, primary_key: true
      add :service_id, :integer, null: false, primary_key: true
      add :length, :bigint, null: false
      add :status, :integer, null: false

      timestamps(type: :utc_datetime)
    end

  end
end
