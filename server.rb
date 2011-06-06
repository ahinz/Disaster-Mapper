require 'sinatra'
require 'geokit'
require 'nokogiri'
require 'open-uri'
require 'rgeo'
require 'rgeo/shapefile'
require 'csv'
require 'json'

include Geokit::Geocoders

def philly_flood(lat,lon)
  factory = RGeo::Cartesian.factory

  p1 = factory.point(lon, lat)

  RGeo::Shapefile::Reader.open('A-GIS/FloodZones/s_fld_haz_ar_reprojected.shp') do |file|
    file.each do |record|
      if (record.geometry.contains?(p1))
        pts = JSON.parse(record.geometry.as_text.gsub("(","[").gsub(")","]").gsub(/(-\d+\.\d+\s+\d+\.\d+)/, "\"\\1\"")[14..-2])
        return { "attr" => record.attributes, "geo" => pts } #record.geometry.as_text.gsub("(","[").gsub(")","]").split(",").map { |x| x.split(" ") }[1..-2] }
      end
    end
  end

end

def jsonp(params,outp)
  outp = JSON.generate(outp)
  if (params[:callback])
    params[:callback] + "(" + outp + ")"
  else
    outp
  end
end

def bootstrap_quake_file(file)
  open(file).read.split("\n").map do |ln|
    ln.strip.split(/\s+/)[2].to_f
  end.max
end

@@max_quake_value = bootstrap_quake_file("2008.US.10hz.10pc50.txt")
puts "==== Found max quake value: " + @@max_quake_value.to_s

def quake_area(file, lat_min, lon_min, lat_max, lon_max,max_quake_value)
  lat_min = lat_min - 0.05
  lon_min = lon_min - 0.05

  open(file).read.split("\n").map do |ln|
    pts = ln.strip.split(/\s+/)
    lon = pts[0].to_f
    lat = pts[1].to_f
    [lat,lon,pts[2].to_f]
  end.select { |lat,lon,val| lat >= lat_min && lat <= lat_max && lon >= lon_min && lon <= lon_max }.map do |lat,lon,val|
    { "lat" => lat,
      "lon" => lon,
      "val" => val,
      "max" => max_quake_value }
  end
end

def quake_file(file, lat_tgt, lon_tgt)
  open(file).read.split("\n").map do |ln|
    pts = ln.strip.split(/\s+/)
    lon = pts[0].to_f
    lat = pts[1].to_f
    
    return pts[2].to_f if (lat <= lat_tgt && lat + 0.05 >= lat_tgt && lon <= lon_tgt && lon + 0.05 >= lon_tgt)
  end
end

def epa_locs(file, lat, lon, dist_miles)
  epas = []
  ll = GeoKit::LatLng.new(lat.to_f, lon.to_f)

  CSV.foreach(file) do |row|
    if (row.length >= 13 && row[12] != nil && row[13] != nil)
      lat = row[12].to_f
      lon = row[13].to_f
      dist = GeoKit::LatLng.new(lat,lon).distance_from(ll, :units => :miles)

      code = ""
      code += row[10] if row[10]
      code += " " + row[11] if row[11]

      epas << { 
        "lat" => lat, 
        "lon" => lon, 
        "dist" => dist,
        "code" => code,
        "url" => row[0],
        "name" => row[1]
      } if dist && dist < dist_miles
    end
  end

  epas.sort do |hash1|
    hash1["dist"]
  end
end

def read_nukes(file, lat, lon, dist_miles)
  nukes = []
  ll = GeoKit::LatLng.new(lat.to_f, lon.to_f)

  File.open(file) do |file|
    file.lines.each do |line|
      parts = line.split(";")
      nukes << { "lat" => parts[1], "lon" => parts[0], "name" => parts[2] } if GeoKit::LatLng.new(parts[1], parts[0]).distance_from(ll, :units => :miles) < dist_miles
    end
  end

  nukes
end

def read_tornado_file(file, lat, lon, dist_miles)
  tornados = []
  ll = GeoKit::LatLng.new(lat.to_f, lon.to_f)

  File.open(file) do |file|
    file.lines.each do |line|
      parts = line.split(",")
      tornados << { 
        "lat" => parts[15], 
        "lon" => parts[16],
        "f" => parts[10],
        "loss" => parts[13],
        "date" => parts[4]
      } if GeoKit::LatLng.new(parts[15], parts[16]).distance_from(ll, :units => :miles) < dist_miles
    end
  end

  tornados
end

get '/geocode' do
  address = params[:address]
  res = MultiGeocoder.geocode(address)

  jsonp(params, { "lat" => res.lat, "lon" => res.lng })
end

get '/epa' do
  address = params[:address]
  res = MultiGeocoder.geocode(address)

  jsonp(params, epa_locs("STATE_SINGLE_PA.csv", res.lat, res.lng, 0.75))
end

get '/flood' do 
  address = params[:address]
  res = MultiGeocoder.geocode(address)

  jsonp(params, philly_flood(res.lat, res.lng))
end

get '/tornados' do
  address = params[:address]
  res = MultiGeocoder.geocode(address)

  jsonp(params, read_tornado_file("2010_torn.csv", res.lat, res.lng, 50))
end

get '/hazards' do
  address = params[:address]
  res = MultiGeocoder.geocode(address)
  
  jsonp(params, read_nukes("NuclearFacilities.csv", res.lat, res.lng, 50))

end

hurricanes = JSON.parse(open("hurricanes.json").read)
puts "==== Loaded " + hurricanes.size.to_s + " hurricanes!"

get '/hurricanes' do
  address = params[:address]
  res = MultiGeocoder.geocode(address)

  dist_miles = 100

  found = hurricanes.select { |h| h["path"].inject(false) do |found,nxt| 
      ll = nxt.split(",")
      found || (GeoKit::LatLng.new(ll[0].to_f,ll[1].to_f).distance_from(res, :units => :miles) < dist_miles)
    end }
      
  jsonp(params, found)
end  

get '/earthquakes/area' do
  jsonp(params, quake_area("2008.US.10hz.10pc50.txt", params[:lat_min].to_f, params[:lon_min].to_f, params[:lat_max].to_f, params[:lon_max].to_f, @@max_quake_value))
end

get '/earthquakes' do
  address = params[:address]
  res = MultiGeocoder.geocode(address)

  jsonp(params, quake_file("2008.US.10hz.10pc50.txt", res.lat, res.lng))
end
