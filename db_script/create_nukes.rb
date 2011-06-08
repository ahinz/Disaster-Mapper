if (ARGV.length != 2)
  puts "Usage: ./nukes dbname nukefile"
  exit(2)
end

require 'sqlite3'

db = SQLite3::Database.new( ARGV.first )

begin
  db.execute("drop table nukes");
  puts "Dropped table"
rescue
  puts "No nukes table"
end

db.execute("create table nukes (id INTEGER PRIMARY KEY, lat REAL, lon REAL, name TEXT, type TEXT, num TEXT)");

File.open(ARGV[1]).read.split("\n")[1..-1].map { |x| x.split(";") }.each do |row|
  db.execute("insert into nukes values ( NULL, ?, ?, ?, ?, ? )", row[1],row[0],row[2],row[3],row[4])
end
