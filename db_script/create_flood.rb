require 'rgeo'
require 'rgeo/shapefile'  
require 'sqlite3'

db = SQLite3::Database.new( ARGV.first )

begin
	db.execute("drop table flood")
	db.execute("drop table flood_gis")
rescue
	puts "No tables to drop"
end

db.execute("create table flood (id INTEGER PRIMARY KEY, FLD_AR_ID TEXT, FLD_ZONE TEXT, FLOODWAY TEXT, SFHA_TF TEXT, V_DATUM TEXT, LEN_UNIT TEXT, AR_REVERT TEXT, SOSURCE_CIT TEXT, HYDRO_ID TEXT, CST_MDL_ID TEXT, BFE_REVERT TEXT, DEP_REVERT TEXT, DEPTH TEXT, VELOCITY TEXT, STATIC_BFE TEXT, lat_min REAL, lat_max REAL, lon_min REAL, lon_max REAL)")
db.execute("create table flood_gis(id INTEGER PRIMARY KEY, flood_id INTEGER, shape_id INTEGER, lat REAL, lon REAL)")

RGeo::Shapefile::Reader.open('A-GIS/FloodZones/s_fld_haz_ar_reprojected.shp') do |file|
    geom_offset = 1

    file.each do |record|
	attr = record.attributes
	next_id = db.get_first_value("select max(id)+1 from flood")
	next_id = 1 unless next_id

	next_gis_id = db.get_first_value("select max(id)+1 from flood_gis")
	next_gis_id = 1 unless next_gis_id

	lon_min =  100000
	lon_max = -100000
	lat_min =  100000
	lat_max = -100000

	record.geometry.each do |g|
		ring = g.exterior_ring()
		pts = ring.num_points		
		(0..(pts-1)).each do |p|
			lon = ring.point_n(p).x()
			lat = ring.point_n(p).y()

			lon_min = lon if lon < lon_min
			lon_max = lon if lon > lon_max
			lat_min = lat if lat < lat_min
			lat_max = lat if lat > lat_max

			db.execute("insert into flood_gis values(?, ?, ?, ?, ?)", next_gis_id, next_id, geom_offset, lat, lon)
			next_gis_id += 1
		end

		geom_offset += 1
	end

	puts "Starting on record #{next_id} [num #{next_gis_id}]"

        db.execute("insert into flood values (#{next_id}, " +
                [attr["FLD_AR_ID"], attr["FLD_ZONE"], attr["FLOODWAY"], attr["SFHA_TF"],attr["V_DATUM"], attr["LEN_UNIT"], attr["AR_REVERT"], attr["SOSURCE_CIT"], attr["HYDRO_ID"], attr["CST_MDL_ID"], attr["BFE_REVERT"],attr["DEP_REVERT"], attr["DEPTH"], attr["VELOCITY"], attr["STATIC_BFE"]].map {|x| "\"" + x.to_s + "\""}.join(",") + ", #{lat_min}, #{lat_max}, #{lon_min}, #{lon_max})")

    end
  end

