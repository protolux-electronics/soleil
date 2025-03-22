defmodule Soleil.Metrics do
  @behaviour NervesHubLink.Extensions.Health.MetricSet

  require Logger

  @impl true
  def sample() do
    {:ok, battery_info} = Soleil.battery_info()

    battery_info
    |> Enum.map(fn {k, v} -> {"Soleil_#{k}", v} end)
    |> Map.new()
  end
end
