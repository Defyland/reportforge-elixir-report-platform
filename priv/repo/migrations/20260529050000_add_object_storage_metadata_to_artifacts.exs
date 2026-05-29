defmodule ReportForge.Repo.Migrations.AddObjectStorageMetadataToArtifacts do
  use Ecto.Migration

  def change do
    alter table(:report_artifacts) do
      add(:storage_key, :string)
      add(:byte_size, :integer)
      add(:checksum, :string)
      modify(:body, :binary, null: true)
    end

    create index(:report_artifacts, [:storage_key])
  end
end
