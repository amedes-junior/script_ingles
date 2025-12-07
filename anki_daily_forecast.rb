#!/usr/bin/env ruby
require 'sqlite3'
require 'date'
require 'optparse'

# Path to Anki database
DB_PATH = File.expand_path("~/Library/Application Support/Anki2/Usuário 1/collection.anki2")

# Default parameters
options = {
  start_date: Date.today,
  end_date: Date.today + 90,
  new_cards_per_day: 10,
  cards_studied_per_day: 100
}

# Parse command line options
OptionParser.new do |opts|
  opts.banner = "Usage: anki_daily_forecast.rb [options]"

  opts.on("-s", "--start DATE", "Start date (YYYY-MM-DD)") do |date|
    options[:start_date] = Date.parse(date)
  end

  opts.on("-e", "--end DATE", "End date (YYYY-MM-DD)") do |date|
    options[:end_date] = Date.parse(date)
  end

  opts.on("-n", "--new-cards NUM", Integer, "New cards per day (default: 10)") do |num|
    options[:new_cards_per_day] = num
  end

  opts.on("-r", "--review-cards NUM", Integer, "Review cards per day (default: 100)") do |num|
    options[:cards_studied_per_day] = num
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

start_date = options[:start_date]
end_date = options[:end_date]
new_cards_per_day = options[:new_cards_per_day]
cards_studied_per_day = options[:cards_studied_per_day]

# Validate dates
if start_date > end_date
  puts "Error: Start date must be before or equal to end date"
  exit 1
end

# Open database connection
db = SQLite3::Database.new(DB_PATH)
db.results_as_hash = true

# Get collection creation timestamp
crt = db.execute("SELECT crt FROM col").first['crt']

# Get current overdue cards
today_day_number = ((Time.now.to_i - crt) / 86400.0).floor

query_overdue = <<-SQL
  SELECT COUNT(*) as total_overdue
  FROM cards
  WHERE queue = 2
    AND type = 2
    AND due < #{today_day_number};
SQL

current_overdue = db.execute(query_overdue).first['total_overdue']

# Function to get cards due on a specific day
def get_cards_due_on_day(db, crt, target_date)
  day_number = ((target_date.to_time.to_i - crt) / 86400.0).floor

  query = <<-SQL
    SELECT COUNT(*) as count
    FROM cards
    WHERE queue = 2
      AND type = 2
      AND due = #{day_number};
  SQL

  result = db.execute(query).first
  result['count']
end

# Display header
puts "=" * 90
puts "                        ANKI DAILY STUDY FORECAST"
puts "=" * 90
puts ""
puts "📅 Date Range: #{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}"
puts "📚 Study Plan: #{cards_studied_per_day} cards/day (#{new_cards_per_day} new + #{cards_studied_per_day - new_cards_per_day} reviews)"
puts "⏰ Current overdue cards: #{current_overdue}"
puts ""
puts "=" * 90

# Display table header
puts ""
puts sprintf("%-5s | %-12s | %-15s | %-15s | %-15s | %s",
             "#", "Date", "Due Reviews", "New Cards", "Overdue", "Total")
puts "-" * 90

# Calculate daily forecast
current_day = start_date
day_number = 1
total_cards_all_days = 0
remaining_overdue = current_overdue
net_progress = cards_studied_per_day - new_cards_per_day

while current_day <= end_date
  # Get cards due on this specific day
  due_reviews = get_cards_due_on_day(db, crt, current_day)

  # Calculate overdue for this day
  if current_day < Date.today
    # Past days - we don't have historical data
    day_overdue = "N/A"
    total_for_day = "N/A"
  elsif current_day == Date.today
    # Today
    day_overdue = current_overdue
    total_for_day = [due_reviews + new_cards_per_day + day_overdue, cards_studied_per_day].max
  else
    # Future days - project overdue reduction
    days_from_today = (current_day - Date.today).to_i
    day_overdue = [remaining_overdue - (days_from_today * net_progress), 0].max

    # Total cards to study = due reviews + new cards + overdue
    # But we'll study up to cards_studied_per_day
    total_cards_available = due_reviews + new_cards_per_day + day_overdue
    total_for_day = total_cards_available
  end

  # Skip lines where due_reviews is 0
  unless due_reviews == 0
    # Format output
    day_str = day_number.to_s
    date_str = current_day.strftime('%Y-%m-%d')
    due_str = due_reviews.to_s
    new_str = new_cards_per_day.to_s
    overdue_str = day_overdue.is_a?(String) ? day_overdue : day_overdue.to_s
    total_str = total_for_day.is_a?(String) ? total_for_day : total_for_day.to_s

    # Highlight today
    if current_day == Date.today
      puts sprintf("%-5s | %-12s | %15s | %15s | %15s | %15s  ← TODAY",
                  day_str, date_str, due_str, new_str, overdue_str, total_str)
    else
      puts sprintf("%-5s | %-12s | %15s | %15s | %15s | %15s",
                  day_str, date_str, due_str, new_str, overdue_str, total_str)
    end
  end

  # Track totals (only for numeric values)
  if total_for_day.is_a?(Integer)
    total_cards_all_days += total_for_day
  end

  # Update remaining overdue for next iteration
  if current_day >= Date.today && day_overdue.is_a?(Integer)
    remaining_overdue = [day_overdue - net_progress, 0].max
  end

  current_day += 1
  day_number += 1
end

puts "=" * 90
puts ""

# Summary statistics
total_days = (end_date - start_date).to_i + 1
future_days = total_days - [0, (Date.today - start_date).to_i].max

puts "📊 SUMMARY STATISTICS"
puts "-" * 90
puts sprintf("  %-35s %10d days", "Total days in range:", total_days)
puts sprintf("  %-35s %10d cards", "Current overdue cards:", current_overdue)
puts sprintf("  %-35s %10d cards/day", "Daily study target:", cards_studied_per_day)
puts sprintf("  %-35s %10d cards/day", "Net progress (reviews - new):", net_progress)

if current_overdue > 0 && net_progress > 0
  days_to_zero = (current_overdue.to_f / net_progress).ceil
  zero_date = Date.today + days_to_zero

  puts sprintf("  %-35s %10d days", "Days to zero overdue:", days_to_zero)
  puts sprintf("  %-35s %10s", "Projected zero date:", zero_date.strftime('%Y-%m-%d'))

  if zero_date <= end_date
    puts ""
    puts "  🎯 You will reach zero overdue cards within this date range! 🎉"
  end
end

puts ""
puts "=" * 90
puts ""

# Legend
puts "📖 LEGEND"
puts "-" * 90
puts "  Due Reviews:  Cards scheduled for review on that specific day"
puts "  New Cards:    New cards you plan to learn that day"
puts "  Overdue:      Cards from previous days not yet reviewed"
puts "  Total:        Total cards available to study that day"
puts ""
puts "Note: Future overdue projections assume you study #{cards_studied_per_day} cards/day"
puts "      and learn #{new_cards_per_day} new cards/day consistently."
puts ""
puts "=" * 90

# Close database
db.close

puts ""
puts "✓ Forecast completed successfully!"
puts ""
