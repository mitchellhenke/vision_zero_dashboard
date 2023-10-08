defmodule Mix.Tasks.VisionZeroDashboard.Data do
  use Mix.Task

  def run(args) do
    current_year = 2023
    last_year = 2022

    {options, _, _} =
      OptionParser.parse(args, switches: [years: :string, download: :boolean])

    years =
      Keyword.get(options, :years, "#{last_year},#{current_year}")
      |> String.split(",")
      |> Enum.map(&String.to_integer/1)

    download =
      Keyword.get(options, :download, false)

    data =
      if download do
        alder_districts =
          File.read!("./data/alder_districts.geojson")
          |> Jason.decode!()
          |> Geo.JSON.decode!()

        HTTPoison.start()

        Enum.map(years, fn year ->
          data =
            get_data(year)
            |> process_and_write_data(year, alder_districts)

          {year, data}
        end)
        |> Enum.into(%{})
      else
        Enum.map(years, fn year ->
          data = read_data(year)
          {year, data}
        end)
        |> Enum.into(%{})
      end

    current_year_serious_crashes =
      Map.fetch!(data, current_year)
      |> Enum.filter(fn crash ->
        Map.fetch!(crash, :severity) in ["K", "A"]
      end)

    current_year_ped_fatalities =
      Enum.filter(current_year_serious_crashes, fn crash ->
        Map.fetch!(crash, :pedestrian)
      end)
      |> Enum.map(fn crash ->
        Map.fetch!(crash, :total_fatalities)
      end)
      |> Enum.sum()

    current_year_ped_severe_injuries =
      Enum.filter(current_year_serious_crashes, fn crash ->
        Map.fetch!(crash, :pedestrian)
      end)
      |> Enum.map(fn crash ->
        Map.fetch!(crash, :total_injuries)
      end)
      |> Enum.sum()

    current_year_bike_fatalities =
      Enum.filter(current_year_serious_crashes, fn crash ->
        Map.fetch!(crash, :bike)
      end)
      |> Enum.map(fn crash ->
        Map.fetch!(crash, :total_fatalities)
      end)
      |> Enum.sum()

    current_year_bike_severe_injuries =
      Enum.filter(current_year_serious_crashes, fn crash ->
        Map.fetch!(crash, :bike)
      end)
      |> Enum.map(fn crash ->
        Map.fetch!(crash, :total_injuries)
      end)
      |> Enum.sum()


    html = File.read!("_public/index.html")
           |> String.replace(~r|<p id="bicyclist-injuries">\d+</p>|, "<p id=\"bicyclist-injuries\">#{current_year_bike_severe_injuries}</p>")
           |> String.replace(~r|<p id="bicyclist-fatalities">\d+</p>|, "<p id=\"bicyclist-fatalities\">#{current_year_bike_fatalities}</p>")
           |> String.replace(~r|<p id="pedestrian-injuries">\d+</p>|, "<p id=\"pedestrian-injuries\">#{current_year_pedestrian_severe_injuries}</p>")
           |> String.replace(~r|<p id="pedestrian-fatalities">\d+</p>|, "<p id=\"pedestrian-fatalities\">#{current_year_pedestrian_fatalities}</p>")
    File.write!("_public/index.html", html)
  end

  def read_data(year) do
    File.read!("_public/data/#{year}.json")
    |> Jason.decode!(keys: :atoms)
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
