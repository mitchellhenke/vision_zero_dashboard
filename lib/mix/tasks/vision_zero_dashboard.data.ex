defmodule Mix.Tasks.VisionZeroDashboard.Data do
  use Mix.Task

  def run(args) do
    HTTPoison.start()
    current_year = NaiveDateTime.utc_now().year
    last_year = current_year - 1
    current_year_data = get_data(current_year)
    last_year_data = get_data(last_year)

    process_and_write_data(current_year_data, current_year)
    process_and_write_data(last_year_data, last_year)

    update_html
  end

  def process_and_write_data(data, year) do
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

        %{
          date: get_in(feature, ["properties", "date"]),
          year: get_in(feature, ["properties", "date"]).year,
          total_fatalities: get_in(feature, ["properties", "totfatl"]),
          total_injuries: get_in(feature, ["properties", "totinj"]),
          severity: get_in(feature, ["properties", "injsvr"]),
          at_roadway: get_in(feature, ["properties", "atrdwy"]),
          on_roadway: get_in(feature, ["properties", "onrdwy"]),
          "65+_driver": get_in(feature, ["properties", "65+drvr"]),
          construction_zone: get_in(feature, ["properties", "conszone"]),
          distracted: get_in(feature, ["properties", "distrctd"]),
          impaired: get_in(feature, ["properties", "impaired"]),
          occupant_protection: get_in(feature, ["properties", "occpprot"]),
          speeding: get_in(feature, ["properties", "speedflag"]),
          teen_driver: get_in(feature, ["properties", "teendrvr"]),
          municipality: get_in(feature, ["properties", "muniname"]),
          county: get_in(feature, ["properties", "cnytname"])
        }
      end)

    File.write!("_public/data/#{year}.json", Jason.encode!(data))
  end

  def get_data(year) do
    url =
      "https://transportal.cee.wisc.edu/partners/community-maps/crash/public/crashesKML.do?filetype=json&startyear=#{year}&endyear=#{year}&county=milwaukee&injsvr=O&injsvr=K&injsvr=A&injsvr=B&injsvr=C"

    resp = HTTPoison.get!(url)
    Jason.decode!(resp.body)
  end
end
