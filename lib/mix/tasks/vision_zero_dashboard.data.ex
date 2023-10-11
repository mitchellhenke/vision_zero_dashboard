defmodule Mix.Tasks.VisionZeroDashboard.Data do
  use Mix.Task

  def run(_args) do
    today = Date.utc_today()
    one_year_ago = Date.add(today, -365)
    current_year = today.year
    last_year = one_year_ago.year

    ytd_data =
      load_data()
      |> Enum.map(fn {year, crashes} ->
        crashes =
          Enum.filter(crashes, fn crash ->
            date = Map.fetch!(crash, :date)
            date_if_it_was_this_year = %{date | year: current_year}
            Date.compare(date_if_it_was_this_year, today) != :gt
          end)

        {year, crashes}
      end)
      |> Enum.into(%{})

    ytd_summaries =
      Enum.map(ytd_data, fn {year, crashes} ->
        {year, calculate_summary(crashes)}
      end)
      |> Enum.into(%{})

    File.write!("_public/data/summary/ytd_summary.json", Jason.encode!(ytd_summaries))
    {stdout, 0} = System.cmd("jq", ["-S", "-c", ".", "_public/data/summary/ytd_summary.json"])
    File.write!("_public/data/summary/ytd_summary.json", stdout)

    last_year_summary = Map.fetch!(ytd_summaries, last_year)
    current_year_summary = Map.fetch!(ytd_summaries, current_year)

    template = File.read!("lib/templates/index.html.eex")

    html =
      EEx.eval_string(template,
        assigns: [
          current_year: current_year,
          total_injuries: current_year_summary.total_severe_injuries,
          total_fatalities: current_year_summary.total_fatalities,
          total_injuries_percent:
            percent_difference(
              last_year_summary.total_severe_injuries,
              current_year_summary.total_severe_injuries
            ),
          total_fatalities_percent:
            percent_difference(
              last_year_summary.total_fatalities,
              current_year_summary.total_fatalities
            ),
          bike_injuries: current_year_summary.bike_severe_injuries,
          bike_fatalities: current_year_summary.bike_fatalities,
          pedestrian_injuries: current_year_summary.pedestrian_severe_injuries,
          pedestrian_fatalities: current_year_summary.pedestrian_fatalities
        ]
      )

    File.write!("_public/index.html", html)
  end

  def load_data() do
    Path.wildcard("_public/data/*.json")
    |> Enum.map(fn path ->
      year =
        Path.basename(path)
        |> String.split(".")
        |> hd()
        |> String.to_integer()

      data =
        File.read!(path)
        |> parse_data()

      {year, data}
    end)
    |> Enum.into(%{})
  end

  def parse_data(content) do
    Jason.decode!(content, keys: :atoms)
    |> Enum.map(fn crash ->
      Map.update!(crash, :date, &Date.from_iso8601!(&1))
    end)
    |> Enum.filter(fn crash ->
      Map.fetch!(crash, :severity) in ["K", "A"]
    end)
  end

  def calculate_summary(crashes) do
    total_fatalities =
      Enum.map(crashes, fn crash ->
        Map.fetch!(crash, :total_fatalities)
      end)
      |> Enum.sum()

    total_severe_injuries =
      Enum.map(crashes, fn crash ->
        Map.fetch!(crash, :total_injuries)
      end)
      |> Enum.sum()

    pedestrian_fatalities =
      Enum.filter(crashes, fn crash ->
        Map.fetch!(crash, :pedestrian)
      end)
      |> Enum.map(fn crash ->
        Map.fetch!(crash, :total_fatalities)
      end)
      |> Enum.sum()

    pedestrian_severe_injuries =
      Enum.filter(crashes, fn crash ->
        Map.fetch!(crash, :pedestrian)
      end)
      |> Enum.map(fn crash ->
        Map.fetch!(crash, :total_injuries)
      end)
      |> Enum.sum()

    bike_fatalities =
      Enum.filter(crashes, fn crash ->
        Map.fetch!(crash, :bike)
      end)
      |> Enum.map(fn crash ->
        Map.fetch!(crash, :total_fatalities)
      end)
      |> Enum.sum()

    bike_severe_injuries =
      Enum.filter(crashes, fn crash ->
        Map.fetch!(crash, :bike)
      end)
      |> Enum.map(fn crash ->
        Map.fetch!(crash, :total_injuries)
      end)
      |> Enum.sum()

    %{
      total_severe_injuries: total_severe_injuries,
      total_fatalities: total_fatalities,
      pedestrian_severe_injuries: pedestrian_severe_injuries,
      pedestrian_fatalities: pedestrian_fatalities,
      bike_severe_injuries: bike_severe_injuries,
      bike_fatalities: bike_fatalities
    }
  end

  def percent_difference(x1, _x2) when x1 == 0 do
    "Inf"
  end

  def percent_difference(x1, x2) do
    ((x2 - x1) / x1)
    |> Kernel.*(100)
    |> round()
  end
end
