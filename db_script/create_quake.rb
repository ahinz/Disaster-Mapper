require 'sqlite3'
require 'csv'

db = SQLite3::Database.new( ARGV.first )

begin  
  db.execute("drop table quake");
  puts "Dropped table"
rescue
  puts "No quake table"
end

files = ARGV[1..-1]

fields = files.map { |k| File.basename(k)[4..-5].gsub(".","_") }

field_list = fields.map { |k| k + " TEXT" }.join(",")

puts "Field List: " + field_list
db.execute("create table quake (id INTEGER PRIMARY KEY, lat_min REAL, lat_max REAL, lon_min REAL, lon_max REAL, " + field_list + ")")
db.execute("create index quake_idx ON quake (lat_min, lon_min, lat_max, lon_max)")

is_first = true
files.zip(fields).each do |file, field|
	puts "Working on file #{file}"
	index = 0 
	lines = open(file).read.split("\n")
	count = lines.size
	upd_stmt = db.prepare("update quake set #{field} = ? where  lat_min = ? AND lon_min = ?")
	ins_stmt = db.prepare("insert into quake (lat_min,lat_max,lon_min,lon_max,#{field}) values (?,?,?,?,?)")
	db.transaction()
	lines.map do |ln|
		index += 1
	    	pts = ln.strip.split(/\s+/)
    		lon = pts[0].to_f
    		lat = pts[1].to_f
		
		if (is_first == false)
			upd_stmt.execute!(pts[2], lat, lon)
		else
			ins_stmt.execute!(lat.to_f, lat.to_f + 0.05, lon.to_f, lon.to_f + 0.05, pts[2])
		end

		if (index % 100000 == 0) 
			puts "Inserted record #{index} of #{count} (#{index.to_f/count.to_f*100.0})"
		end
	end
	db.commit()

	is_first = false
end
