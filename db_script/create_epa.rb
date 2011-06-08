if (ARGV.length < 2 || ARGV.length > 3)
  puts "Usage: create_epa.rb dbname epa_file [--append]"
end

require 'sqlite3'
require 'csv'

db = SQLite3::Database.new( ARGV.first )

if (ARGV.length == 2 || ARGV[2] != "--append")
  begin
    db.execute("drop table epa");
    puts "Dropped table"
  rescue
    puts "No epa table"
  end
end
  
db.execute("create table epa (id INTEGER PRIMARY KEY, lat REAL, lon REAL, code TEXT, url TEXT, name TEXT)")

recs = 0
CSV.foreach(ARGV[1]) do |row|
    if (row.length >= 13 && row[12] != nil && row[13] != nil)
      lat = row[12].to_f
      lon = row[13].to_f
      
      code = ""
      code += row[10] if row[10]
      code += " " + row[11] if row[11]

      db.execute("insert into epa values(NULL, ?, ?, ?, ?, ?)", lat, lon, code, row[0], row[1])
      recs += 1
    end
end

puts "Inserted " + recs.to_s + " epa records"
