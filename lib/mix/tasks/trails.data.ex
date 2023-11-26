defmodule Mix.Tasks.Trails.Data do
  use Mix.Task
  require Logger
  alias NimbleCSV.RFC4180, as: CSV

  @trail_names [
    "Beerline at Abert",
    "KKRT at Rosedale",
    "KKRT at Maple",
    "HAST at 16th",
    "Marsupial Bridge",
    "OLT South Shore"
  ]

  def run(_args) do
  end

  def convert_csv(string) do
    values =
      CSV.parse_string(string)
      # year, month, month_name, day, day_of_week, day_name, hour, lat, long, trail, flow_identifier, site_nickname, direction, trail_users
      |> Enum.drop(1)
      |> Enum.reduce(%{}, fn [year, month, _, day, _, _, hour, _, _, _, _, name, _, count], map ->
        date =
          Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))

        if rem(System.monotonic_time(), 1000) == 0 do
          IO.inspect(date)
        end

        hour = String.to_integer(hour)
        count = String.to_integer(count)

        name =
          case name do
            "Beerline" -> "Beerline at Abert"
            "KKRT (I-94)" -> "KKRT at Rosedale"
            "KKRT (Maple)" -> "KKRT at Maple"
            "HAST" -> "HAST at 16th"
            "Marsupial Bridge" -> "Marsupial Bridge"
            "OLT (New)" -> "OLT South Shore"
            "OLT (Old)" -> "OLT South Shore"
            unknown -> raise "oops, unknown site: #{unknown}"
          end

        key = "#{date.year}-#{date.month}-#{date.day}-#{hour}-#{name}"

        row = %{date: Date.to_iso8601(date), hour: hour, name: name, count: count}

        Map.update(map, key, row, fn existing_row ->
          %{existing_row | count: existing_row.count + count}
        end)
      end)
      |> Map.values()
      |> Enum.sort()

    csv_values =
      Enum.map(values, fn row ->
        [row.date, row.hour, row.name, row.count]
      end)

    content =
      ([["date", "hour", "counter_location", "trail_count"]] ++ csv_values)
      |> CSV.dump_to_iodata()
      |> IO.iodata_to_binary()

    File.write!("tmp.csv", content)
    File.write!("data.json", Jason.encode!(values))

    values
  end

  def daily_json(data) do
    values =
      Enum.reduce(data, %{}, fn row, map ->
        %{date: date, name: name, count: count} = row
        key = "#{date}-#{name}"

        row = %{date: date, name: name, count: count}

        Map.update(map, key, row, fn existing_row ->
          %{existing_row | count: existing_row.count + count}
        end)
      end)
      |> Map.values()
      |> Enum.sort_by(&[&1.date, &1.name])

    csv_values =
      Enum.map(values, fn row ->
        [row.date, row.name, row.count]
      end)

    content =
      ([["date", "counter_location", "trail_count"]] ++ csv_values)
      |> CSV.dump_to_iodata()
      |> IO.iodata_to_binary()

    File.write!("daily.csv", content)
    json = %{trail_names: @trail_names, data: values}
    File.write!("daily.json", Jason.encode!(json))
  end

  def monthly_json(data) do
    values =
      Enum.reduce(data, %{}, fn row, map ->
        %{date: date, name: name, count: count} = row
        date = %{Date.from_iso8601!(date) | day: 1}
        key = "#{date}-#{name}"

        row = %{date: date, name: name, count: count}

        Map.update(map, key, row, fn existing_row ->
          %{existing_row | count: existing_row.count + count}
        end)
      end)
      |> Map.values()
      |> Enum.sort_by(&[&1.date, &1.name])

    csv_values =
      Enum.map(values, fn row ->
        [row.date, row.name, row.count]
      end)

    content =
      ([["date", "counter_location", "trail_count"]] ++ csv_values)
      |> CSV.dump_to_iodata()
      |> IO.iodata_to_binary()

    File.write!("monthly.csv", content)
    json = %{trail_names: @trail_names, data: values}
    File.write!("monthly.json", Jason.encode!(json))
  end
end
