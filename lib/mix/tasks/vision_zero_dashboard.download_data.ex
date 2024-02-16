defmodule Mix.Tasks.VisionZeroDashboard.DownloadData do
  use Mix.Task

  def run(args) do
    today = Date.utc_today()
    one_year_ago = Date.add(today, -365)
    current_year = today.year
    last_year = one_year_ago.year

    {options, _, _} =
      OptionParser.parse(args, switches: [years: :string])

    years =
      Keyword.get(options, :years, "#{last_year},#{current_year}")
      |> String.split(",")
      |> Enum.map(&String.to_integer/1)

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
          motorcycle: get_in(feature, ["properties", "mcycflag"]) == "Y",
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

    data_path = "data/vision_zero/#{year}.json"
    public_path = "_public/data/vision_zero/#{year}.json"

    find_new(data, data_path)

    encoded = Jason.encode!(data)
    File.write!(data_path, encoded)
    File.write!(public_path, encoded)
    {stdout, 0} = System.cmd("jq", ["-S", ".", data_path])
    File.write!(data_path, stdout)
    {stdout, 0} = System.cmd("jq", ["-S", "-c", ".", public_path])
    File.write!(public_path, stdout)
    data
  end

  def find_new(new_data, existing_path) do
    with {:ok, email_addresses_comma} when is_binary(email_addresses_comma) <-
           System.fetch_env("EMAIL_RECIPIENTS"),
         email_addresses <- String.split(email_addresses_comma, ","),
         {:ok, api_key} when is_binary(api_key) <- System.fetch_env("MAILGUN_API_KEY"),
         {:ok, existing} <- File.read(existing_path),
         {:ok, json} <- Jason.decode(existing) do
      new_crashes =
        Enum.filter(new_data, fn crash ->
          !Enum.find(json, fn existing_crash ->
            Map.fetch!(existing_crash, "id") == crash.id
          end)
        end)

      cond do
        length(new_crashes) > 50 ->
          raise "Too many crashes?"

        length(new_crashes) > 0 ->
          send_emails(new_crashes, email_addresses, api_key)

        true ->
          IO.inspect("No new crashes, not sending email")
      end
    else
      e ->
        IO.inspect("#{e} - maybe new year?")
    end
  end

  def send_emails(crashes, email_addresses, api_key) do
    text =
      Enum.map(crashes, fn crash ->
        ~s"""
        Id: #{crash.id}
        Date: #{crash.date}
        Fatalaties: #{crash.total_fatalities}
        Injuries: #{crash.total_injuries}
        Bicyclist: #{crash.bike}
        Pedestrian: #{crash.pedestrian}
        Motorcycle: #{crash.motorcycle}
        Severity: #{crash.severity}
        Intersection: #{crash.on_roadway} / #{crash.at_roadway}
        Aldermanic District: #{crash.alder_district}
        -----------------------------------------------------
        """
      end)
      |> Enum.join("\n")

    auth = Base.encode64("api:#{api_key}")

    req_body =
      URI.encode_query(%{
        "from" => "data@betterstreetsmke.com",
        "to" => Enum.join(email_addresses, ", "),
        "subject" => "New Crash - Vision Zero Dashboard Notification",
        "text" => text
      })

    {:ok, %{status_code: 200}} =
      HTTPoison.post(
        "https://api.mailgun.net/v3/betterstreetsmke.com/messages",
        req_body,
        [
          {"Content-Type", "application/x-www-form-urlencoded"},
          {"Authorization", "Basic #{auth}"}
        ]
      )
  end

  def get_data(year) do
    url =
      "https://transportal.cee.wisc.edu/partners/community-maps/crash/public/crashesKML.do?filetype=json&startyear=#{year}&endyear=#{year}&county=milwaukee&injsvr=O&injsvr=K&injsvr=A&injsvr=B&injsvr=C"

    resp = HTTPoison.get!(url)
    Jason.decode!(resp.body)
  end
end
