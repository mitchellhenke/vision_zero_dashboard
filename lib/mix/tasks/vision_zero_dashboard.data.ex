defmodule Mix.Tasks.VisionZeroDashboard.Data do
  use Mix.Task

  def run(_args) do
    today = Date.utc_today()
    one_year_ago = Date.add(today, -365)
    current_year = today.year
    last_year = one_year_ago.year

    data =
      Enum.map([last_year, current_year], fn year ->
        data = read_data(year)
        {year, data}
      end)
      |> Enum.into(%{})

    current_year_serious_crashes =
      Map.fetch!(data, current_year)
      |> Enum.filter(fn crash ->
        Map.fetch!(crash, :severity) in ["K", "A"]
      end)

    last_year_serious_crashes_to_date =
      Map.fetch!(data, last_year)
      |> Enum.filter(fn crash ->
        date =
          Map.fetch!(crash, :date)

        Map.fetch!(crash, :severity) in ["K", "A"] &&
          date.year == last_year && Date.compare(date, one_year_ago) == :lt
      end)

    current_year_summary = calculate_summary(current_year_serious_crashes)
    last_year_summary = calculate_summary(last_year_serious_crashes_to_date)

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

    File.write!("_public/index.html", html)
  end

  def read_data(year) do
    File.read!("_public/data/#{year}.json")
    |> Jason.decode!(keys: :atoms)
    |> Enum.map(fn crash ->
      Map.update!(crash, :date, &Date.from_iso8601!(&1))
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

  def process_and_write_data(data, year, alder_districts) do
    data =
      Map.get(data, "features")
      |> Enum.filter(fn feature ->
        get_in(feature, ["properties", "muniname"]) == "MILWAUKEE" &&
          (get_in(feature, ["properties", "injsvr"]) == "A" ||
             get_in(feature, ["properties", "injsvr"]) == "K")
      end)
      |> Enum.map(fn feature ->
        feature =
          update_in(feature, ["properties", "date"], fn string_date ->
            [month, day, year] = String.split(string_date, "/")

            Date.new!(
              String.to_integer(year),
              String.to_integer(month),
              String.to_integer(day)
            )
          end)
          |> update_in(["properties", "totfatl"], &String.to_integer/1)
          |> update_in(["properties", "totinj"], &String.to_integer/1)

        district =
          with [x, y] <- get_in(feature, ["geometry", "coordinates"]),
               point <- %Geo.Point{coordinates: {x, y}, srid: 4326},
               alder when not is_nil(alder) <-
                 Enum.find(alder_districts.geometries, &Topo.contains?(&1, point)),
               {:ok, district} <- Map.fetch(alder.properties, "DISTRICT") do
            district
          end

        {flags, properties} = Map.pop(Map.get(feature, "properties"), "flags")
        feature = Map.put(feature, "properties", Map.merge(properties, flags))

        %{
          id: Map.fetch!(feature, "id"),
          date: get_in(feature, ["properties", "date"]),
          year: get_in(feature, ["properties", "date"]).year,
          total_fatalities: get_in(feature, ["properties", "totfatl"]),
          total_injuries: get_in(feature, ["properties", "totinj"]),
          bike: get_in(feature, ["properties", "bikeflag"]) == "Y",
          pedestrian: get_in(feature, ["properties", "pedflag"]) == "Y",
          severity: get_in(feature, ["properties", "injsvr"]),
          at_roadway: get_in(feature, ["properties", "atrdwy"]),
          on_roadway: get_in(feature, ["properties", "onrdwy"]),
          "65+_driver": get_in(feature, ["properties", "65+drvr"]) == "Y",
          construction_zone: get_in(feature, ["properties", "conszone"]) == "Y",
          distracted: get_in(feature, ["properties", "distrctd"]) == "Y",
          impaired: get_in(feature, ["properties", "impaired"]) == "Y",
          occupant_protection: get_in(feature, ["properties", "occpprot"]) == "Y",
          speeding: get_in(feature, ["properties", "speedflag"]) == "Y",
          teen_driver: get_in(feature, ["properties", "teendrvr"]) == "Y",
          municipality: get_in(feature, ["properties", "muniname"]),
          county: get_in(feature, ["properties", "cnytname"]),
          alder_district: district,
          coordinates: get_in(feature, ["geometry", "coordinates"]) || []
        }
      end)
      |> Enum.sort_by(&Map.fetch!(&1, :id))

    File.write!("data/#{year}.json", Jason.encode!(data, pretty: true))
    File.write!("_public/data/#{year}.json", Jason.encode!(data))
    data
  end

  def get_data(year) do
    url =
      "https://transportal.cee.wisc.edu/partners/community-maps/crash/public/crashesKML.do?filetype=json&startyear=#{year}&endyear=#{year}&county=milwaukee&injsvr=O&injsvr=K&injsvr=A&injsvr=B&injsvr=C"

    resp = HTTPoison.get!(url)
    Jason.decode!(resp.body)
  end
end
