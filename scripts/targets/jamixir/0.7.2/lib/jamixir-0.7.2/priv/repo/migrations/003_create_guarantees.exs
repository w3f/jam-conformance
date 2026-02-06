defmodule Jamixir.Repo.Migrations.CreateGuarantees do
  use Ecto.Migration

  def change do
    create table(:guarantees, primary_key: false) do
      add :core_index, :integer, null: false, primary_key: true
      add :work_report_hash, :blob, null: false
      add :timeslot, :integer, null: false
      add :credentials, :blob, null: false
      add :status, :string, null: false, default: "pending"
      add :included_in_block, :blob

      timestamps(type: :utc_datetime)
    end

    # Additional indexes for queries
    create index(:guarantees, [:work_report_hash])
    create index(:guarantees, [:status])
    create index(:guarantees, [:timeslot])
  end
end
