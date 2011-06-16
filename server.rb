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
require File.dirname(__FILE__) + "/gis.rb"

def sql_con()
  @@sql_con ||= SQLite3::Database.new( "devdb.db" )
end

def philly_flood(lat,lon)
  db = sql_con()

  valid_shapes = {}
  cols = nil
  db.execute2("select * from flood where #{lat} >= lat_min AND #{lat} <= lat_max AND #{lon} >= lon_min AND #{lon} <= lon_max") do |row|
    if (cols == nil)
      cols = row
    else      
      id = row[cols.index("id")]
      shapes = Hash.new
      db.execute("select * from flood_gis where flood_id = #{id}") do |gis_row|
        shape = shapes[gis_row[2]]
        if (shape == nil)
          shape = []
          shapes[gis_row[2]] = []
        end

        shape << [gis_row[4].to_f,gis_row[3].to_f]
      end

      shape_geo = shapes.select do |shape_id,points|
        contains_point?(lon.to_f, lat.to_f, points)
      end

      if (shape_geo.size > 0)
        new_shapes = { 
          "attr" => cols.zip(row).inject(Hash.new){|h,(k,v)| h[k] = v; h},
          "geo" => shape_geo.map { |k,v| v }
        }
        
        valid_shapes = valid_shapes.merge(new_shapes)
      end
    end
  end

  valid_shapes
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
    
    return { "10hz.10pc50" => pts[2].to_f } if (lat <= lat_tgt && lat + 0.05 >= lat_tgt && lon <= lon_tgt && lon + 0.05 >= lon_tgt)
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
	puts "----\n"
lat = lat.to_f
lon = lon.to_f
  lat_d = calc_lat_delta(dist_miles).to_f
  lon_d = calc_lon_delta(dist_miles).to_f

	puts "'lat: #{lat}'\n"
	puts "'lon: #{lon}'\n"
	puts "'lon_d: #{lon_d}\n"
	puts "'lat_d: #{lat_d}\n"

	puts "---EOM---\n"
  "lat <= #{(lat + lat_d).to_s} AND lat >= #{(lat - lat_d).to_s} AND lon <= #{(lon + lon_d).to_s} AND lon >= #{(lon - lon_d).to_s}"
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

def lat_lon_from_params(params)
  if (params[:lat] == nil || params[:lon] == nil)
	puts "Failed to find lat/lon"
	require 'pp'
	pp params
    address = params[:address]
    res = MultiGeocoder.geocode(address)

    [res.lat, res.lng]
  else
    [params[:lat], params[:lon]]
  end
end

get '/geocode' do
  address = params[:address]
  res = MultiGeocoder.geocode(address)

  jsonp(params, { "lat" => res.lat, "lon" => res.lng })
end

get '/epa' do
  lat,lon = lat_lon_from_params(params)
  jsonp(params, epa_locs("STATE_SINGLE_PA.csv", lat, lon, 0.75))
end

get '/floods' do 
  lat,lon = lat_lon_from_params(params)
  jsonp(params, philly_flood(lat, lon))
end

get '/tornados' do
  lat,lon = lat_lon_from_params(params)
  jsonp(params, read_tornado_file("2010_torn.csv", lat, lon, 50))
end

get '/hazards' do
  lat,lon = lat_lon_from_params(params)
  jsonp(params, read_nukes("NuclearFacilities.csv", lat, lon, 50))

end

hurricanes = JSON.parse(open("hurricanes.json").read)
puts "==== Loaded " + hurricanes.size.to_s + " hurricanes!"

get '/hurricanes' do
  lat,lon = lat_lon_from_params(params)
  res = GeoKit::LatLng.new(lat,lon)

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

get '/earthquake' do
  lat,lon = lat_lon_from_params(params)
	quake = quake_file("2008.US.10hz.10pc50.txt", lat.to_f, lon.to_f)
require 'pp'; pp quake
  jsonp(params, quake)
end
