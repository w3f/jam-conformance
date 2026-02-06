defmodule Jamixir.Repo.Migrations.CreateJudgements do
  use Ecto.Migration

  def change do
    create table(:judgements, primary_key: false) do
      add :epoch, :integer, null: false, primary_key: true
      add :work_report_hash, :blob, null: false, primary_key: true
      add :validator_index, :integer, null: false, primary_key: true
      add :signature, :blob, null: false
      add :vote, :boolean, null: false

      timestamps(type: :utc_datetime)
    end

    # Additional indexes if needed for queries
    create index(:judgements, [:work_report_hash])
    create index(:judgements, [:validator_index])
  end
end
