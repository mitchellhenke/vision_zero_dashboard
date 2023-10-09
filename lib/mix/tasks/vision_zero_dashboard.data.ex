defmodule Mix.Tasks.VisionZeroDashboard.Data do
  use Mix.Task

  def run(_args) do
    today = Date.utc_today()
    one_year_ago = Date.add(today, -365)
    current_year = today.year
    last_year = one_year_ago.year

    data =
      load_data()

    summaries =
      Enum.map(data, fn {year, data} ->
        {year, calculate_summary(data)}
      end)
      |> Enum.into(%{})

    last_year_serious_crashes_to_date =
      Map.fetch!(data, last_year)
      |> Enum.filter(fn crash ->
        date =
          Map.fetch!(crash, :date)

        date.year == last_year && Date.compare(date, one_year_ago) == :lt
      end)

    last_year_summary = calculate_summary(last_year_serious_crashes_to_date)
    current_year_summary = Map.fetch!(summaries, current_year)

    html =
      File.read!("_public/index.html")
      |> String.replace(
        ~r|<p id="bicyclist-injuries">\d+</p>|,
        "<p id=\"bicyclist-injuries\">#{current_year_summary.bike_severe_injuries}</p>"
      )
      |> String.replace(
        ~r|<p id="bicyclist-fatalities">\d+</p>|,
        "<p id=\"bicyclist-fatalities\">#{current_year_summary.bike_fatalities}</p>"
      )
      |> String.replace(
        ~r|<p id="pedestrian-injuries">\d+</p>|,
        "<p id=\"pedestrian-injuries\">#{current_year_summary.pedestrian_severe_injuries}</p>"
      )
      |> String.replace(
        ~r|<p id="pedestrian-fatalities">\d+</p>|,
        "<p id=\"pedestrian-fatalities\">#{current_year_summary.pedestrian_fatalities}</p>"
      )
      |> String.replace(
        ~r|<p id="total-injuries">\d+</p>|,
        "<p id=\"total-injuries\">#{current_year_summary.total_severe_injuries}</p>"
      )
      |> String.replace(
        ~r|<p id="total-fatalities">\d+</p>|,
        "<p id=\"total-fatalities\">#{current_year_summary.total_fatalities}</p>"
      )
      |> String.replace(
        ~r|<p id="total-injuries-percent">-?\d+|,
        "<p id=\"total-injuries-percent\">#{percent_difference(last_year_summary.total_severe_injuries, current_year_summary.total_severe_injuries)}"
      )
      |> String.replace(
        ~r|<p id="total-fatalities-percent">-?\d+|,
        "<p id=\"total-fatalities-percent\">#{percent_difference(last_year_summary.total_fatalities, current_year_summary.total_fatalities)}"
      )
      |> String.replace(
        ~r|<h2 id="year-header">-?\d+|,
        "<h2 id=\"year-header\">#{current_year}"
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
