if (ARGV.length < 2 || ARGV.length > 3)
  puts "Usage: create_torn.rb dbname epa_file [--append]"
end

require 'sqlite3'
require 'csv'

db = SQLite3::Database.new( ARGV.first )

if (ARGV.length == 2 || ARGV[2] != "--append")
  begin
    db.execute("drop table torn");
    puts "Dropped table"
  rescue
    puts "No torn table"
  end
end
  
db.execute("create table torn (id INTEGER PRIMARY KEY, lat REAL, lon REAL, f TEXT, loss TEXT, date TEXT)")

recs = 0
File.open(ARGV[1]) do |file|
  file.lines.each do |line|
    parts = line.split(",")
    db.execute("insert into torn values(NULL, ?, ?, ?, ?, ?)", parts[15], parts[16], parts[10], parts[13], parts[4])
    recs += 1
  end
end

puts "Inserted " + recs.to_s + " tornado records"
