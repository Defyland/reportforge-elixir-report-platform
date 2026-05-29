defmodule ReportForge.ArtifactStorage.Key do
  @moduledoc false

  def build(attrs) do
    report_id = Map.fetch!(attrs, :report_id)
    id = Map.fetch!(attrs, :id)
    filename = attrs |> Map.fetch!(:filename) |> Path.basename()

    Path.join([report_id, "#{id}-#{filename}"])
  end
end
