#!/usr/bin/env ruby
require 'sqlite3'

# Path to Anki database
DB_PATH = File.expand_path("~/Library/Application Support/Anki2/Usuário 1/collection.anki2")

# Open database connection
db = SQLite3::Database.new(DB_PATH)
db.results_as_hash = true

# SQL query to get overdue cards by day
query = <<-SQL
  SELECT
    date(1479276000 + (due * 86400), 'unixepoch') as due_date,
    COUNT(*) as overdue_count
  FROM cards
  WHERE queue = 2
    AND type = 2
    AND due < (strftime('%s', 'now') - 1479276000) / 86400
    AND date(1479276000 + (due * 86400), 'unixepoch') >= '2025-06-10'
    AND date(1479276000 + (due * 86400), 'unixepoch') <= '2025-10-18'
  GROUP BY date(1479276000 + (due * 86400), 'unixepoch')
  ORDER BY due_date;
SQL

# Execute query
results = db.execute(query)

# Display results in table format
puts "=" * 50
puts "OVERDUE CARDS BY DAY"
puts "=" * 50
puts "%-15s | %s" % ["Date", "Overdue Count"]
puts "-" * 50

total_cards = 0
results.each do |row|
  puts "%-15s | %13d" % [row['due_date'], row['overdue_count']]
  total_cards += row['overdue_count']
end

puts "-" * 50
puts "%-15s | %13d" % ["TOTAL", total_cards]
puts "=" * 50

# Calculate statistics
if results.length > 0
  counts = results.map { |r| r['overdue_count'] }
  average = total_cards.to_f / results.length
  min_count = counts.min
  max_count = counts.max

  puts "\nSTATISTICS:"
  puts "  Total days: #{results.length}"
  puts "  Total overdue cards: #{total_cards}"
  puts "  Average per day: #{average.round(2)}"
  puts "  Minimum per day: #{min_count}"
  puts "  Maximum per day: #{max_count}"

  # Find dates with min/max
  min_date = results.find { |r| r['overdue_count'] == min_count }['due_date']
  max_dates = results.select { |r| r['overdue_count'] == max_count }.map { |r| r['due_date'] }

  puts "  Minimum on: #{min_date}"
  puts "  Maximum on: #{max_dates.join(', ')}"
end

# Close database
db.close

puts "\n✓ Query completed successfully!"
