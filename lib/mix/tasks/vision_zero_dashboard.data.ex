defmodule Mix.Tasks.VisionZeroDashboard.Data do
  use Mix.Task
  require Logger

  def run(_args) do
    today = Date.utc_today()
    one_year_ago = Date.add(today, -365)
    current_year = today.year
    last_year = one_year_ago.year

    {current_year, last_year} =
      if today.month == 1 && today.day < 28 do
        {current_year - 1, last_year - 1}
      else
        {current_year, last_year}
      end

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

    File.write!("_public/data/vision_zero/summary/ytd_summary.json", JSON.encode!(ytd_summaries))

    {stdout, 0} =
      System.cmd("jq", ["-S", "-c", ".", "_public/data/vision_zero/summary/ytd_summary.json"])

    File.write!("_public/data/vision_zero/summary/ytd_summary.json", stdout)

    last_year_summary = Map.fetch!(ytd_summaries, last_year)
    current_year_summary = Map.fetch!(ytd_summaries, current_year)

    vz_dashboard_assigns = [
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
      pedestrian_fatalities: current_year_summary.pedestrian_fatalities,
      motorcyclist_injuries: current_year_summary.motorcycle_severe_injuries,
      motorcyclist_fatalities: current_year_summary.motorcycle_fatalities,
      motorist_injuries: current_year_summary.motorist_severe_injuries,
      motorist_fatalities: current_year_summary.motorist_fatalities
    ]

    assigns = %{
      "vision_zero" => vz_dashboard_assigns,
      "index" => [],
      "trails" => []
    }

    compile_templates(assigns)
  end

  def compile_templates(assigns_map) do
    layout = File.read!("lib/templates/layouts/root.html.eex")

    Path.wildcard("lib/templates/*.html.eex")
    |> Enum.each(fn path ->
      filename = Path.basename(path, ".html.eex")
      assigns = Map.fetch!(assigns_map, filename)
      template = File.read!(path)

      html =
        EEx.eval_string(template,
          assigns: assigns
        )

      html =
        EEx.eval_string(layout,
          assigns: [inner_content: html]
        )

      File.write!("_public/#{filename}.html", html)

      Logger.info(filename)
    end)
  end

  def load_data() do
    Path.wildcard("data/vision_zero/*.json")
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
    JSON.decode!(content)
    |> Enum.map(fn crash ->
      Enum.map(crash, fn {key, value} ->
        {String.to_atom(key), value}
      end)
      |> Enum.into(%{})
    end)
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

    motorcycle_fatalities =
      Enum.filter(crashes, fn crash ->
        Map.fetch!(crash, :motorcycle)
      end)
      |> Enum.map(fn crash ->
        Map.fetch!(crash, :total_fatalities)
      end)
      |> Enum.sum()

    motorcycle_severe_injuries =
      Enum.filter(crashes, fn crash ->
        Map.fetch!(crash, :motorcycle)
      end)
      |> Enum.map(fn crash ->
        Map.fetch!(crash, :total_injuries)
      end)
      |> Enum.sum()

    motorist_severe_injuries =
      total_severe_injuries - pedestrian_severe_injuries - bike_severe_injuries -
        motorcycle_severe_injuries

    motorist_fatalities =
      total_fatalities - pedestrian_fatalities - bike_fatalities - motorcycle_fatalities

    %{
      total_severe_injuries: total_severe_injuries,
      total_fatalities: total_fatalities,
      pedestrian_severe_injuries: pedestrian_severe_injuries,
      pedestrian_fatalities: pedestrian_fatalities,
      bike_severe_injuries: bike_severe_injuries,
      bike_fatalities: bike_fatalities,
      motorcycle_severe_injuries: motorcycle_severe_injuries,
      motorcycle_fatalities: motorcycle_fatalities,
      motorist_severe_injuries: motorist_severe_injuries,
      motorist_fatalities: motorist_fatalities
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
