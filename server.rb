require 'sinatra'
require 'geokit'
require 'nokogiri'
require 'open-uri'
require 'rgeo'
require 'rgeo/shapefile'
require 'csv'
require 'json'

include Geokit::Geocoders
require  'sqlite3'

def sql_con()
  @@sql_con ||= SQLite3::Database.new( "devdb.db" )
end

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

@@max_quake_value = 2.3 #= bootstrap_quake_file("2008.US.10hz.10pc50.txt")
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


# These are maximums
def calc_lat_delta(dist_miles)
  dist_miles / 70.0
end

def calc_lon_delta(dist_miles)
  dist_miles / 70.0
end

def gen_gis_where_clause(lat, lon, dist_miles)
  lat_d = calc_lat_delta(dist_miles)
  lon_d = calc_lon_delta(dist_miles)

  "lat <= #{lat + lat_d} AND lat >= #{lat - lat_d} AND lon <= #{lon + lon_d} AND lon >= #{lon - lon_d}"
end

def dist?(lat, lon, ll, dist_miles)

end

def exec_bounded_query(stmt, lat, lon, ll, dist_miles)
  puts "exec: " + stmt
  cols = nil
  values = []
  sql_con().execute2(stmt) do |row|
    if (cols == nil)
      cols = row
    else
      hash = cols.zip(row).inject(Hash.new) { |hash, (k,v)| hash[k] = v; hash }
      dist = GeoKit::LatLng.new(lat, lon).distance_from(ll, :units => :miles)
      if (dist <= dist_miles)
        values << hash.merge({"dist" => dist })
      end
    end
  end

  values
end

def read_nukes(file, lat, lon, dist_miles)
  ll = GeoKit::LatLng.new(lat.to_f, lon.to_f)
  stmt = "select * from nukes where " + gen_gis_where_clause(lat, lon, dist_miles)

  exec_bounded_query(stmt, lat, lon, ll, dist_miles)
end

def epa_locs(file, lat, lon, dist_miles)
  ll = GeoKit::LatLng.new(lat.to_f, lon.to_f)

  exec_bounded_query("select * from epa where " + gen_gis_where_clause(lat, lon, dist_miles), lat, lon, ll, dist_miles)
end


def read_tornado_file(file, lat, lon, dist_miles)
  ll = GeoKit::LatLng.new(lat.to_f, lon.to_f)

  exec_bounded_query("select * from torn where " + gen_gis_where_clause(lat, lon, dist_miles), lat, lon, ll, dist_miles)
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
