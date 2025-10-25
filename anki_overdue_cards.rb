#!/usr/bin/env ruby
require 'sqlite3'
require 'date'

# Path to Anki database
DB_PATH = File.expand_path("~/Library/Application Support/Anki2/Usuário 1/collection.anki2")

# Open database connection
db = SQLite3::Database.new(DB_PATH)
db.results_as_hash = true

# Get today's date
today = Date.today.to_s
total_cards_study_day = 100

# SQL query to get overdue cards by day
query = <<-SQL
  SELECT
    date(1479276000 + (due * 86400), 'unixepoch') as due_date,
    COUNT(*) as overdue_count
  FROM cards
  WHERE queue = 2
    AND type = 2
    AND due < (strftime('%s', 'now') - 1479276000) / 86400
    AND date(1479276000 + (due * 86400), 'unixepoch') >= '2025-06-01'
    AND date(1479276000 + (due * 86400), 'unixepoch') <= '#{today}'
  GROUP BY date(1479276000 + (due * 86400), 'unixepoch')
  ORDER BY due_date;
SQL

# Execute query
results = db.execute(query)

# Display results in table format
puts "=" * 70
puts "OVERDUE CARDS BY DAY"
puts "=" * 70
puts "%-15s | %13s | %s" % ["Date", "Overdue Count", "Cumulative Sum"]
puts "-" * 70

total_cards = 0
cumulative_sum = 0
results.each do |row|
  cumulative_sum += row['overdue_count']
  puts "%-15s | %13d | %14d" % [row['due_date'], row['overdue_count'], cumulative_sum]
  total_cards += row['overdue_count']
end

puts "-" * 70
puts "%-15s | %13d | %14d" % ["TOTAL", total_cards, cumulative_sum]
puts "=" * 70

# Calculate statistics
if results.length > 0
  counts = results.map { |r| r['overdue_count'] }
  average = total_cards.to_f / results.length
  min_count = counts.min
  max_count = counts.max

  puts "\n 📊 STATISTICS:"
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

  puts "  📈 Total day to 0 (zero) overdue: #{(total_cards / total_cards_study_day).to_i + 1} days"
  puts "  📅 Expected date to 0(zero) overdue: #{(Date.today + ((total_cards / total_cards_study_day).to_i + 1)).to_s} 🎯"
end

# Close database
db.close

puts "\n✓ Query completed successfully!"
