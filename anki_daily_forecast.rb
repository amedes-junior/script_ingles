#!/usr/bin/env ruby
require 'sqlite3'
require 'date'
require 'optparse'

# Path to Anki database
DB_PATH = File.expand_path("~/Library/Application Support/Anki2/Usuário 1/collection.anki2")

# Default parameters
options = {
  start_date: Date.today,
  end_date: Date.today + 720,
  new_cards_per_day: 5,
  cards_studied_per_day: 120
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
puts "=" * 115
puts "                        ANKI DAILY STUDY FORECAST"
puts "=" * 115
puts ""
puts "📅 Date Range: #{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}"
puts "📚 Study Plan: #{cards_studied_per_day} reviews/day limit + #{new_cards_per_day} new cards/day (extras, fora do limite)"
puts "⏰ Current overdue cards: #{current_overdue}"
puts ""
puts "=" * 115

# Display table header
puts ""
puts sprintf("%-5s | %-12s | %-13s | %-12s | %-10s | %-10s | %-13s | %s",
             "#", "Date", "Due Reviews", "Overdue In", "Total", "Studied", "New Overdue", "New Cards")
puts "-" * 115

# Calculate daily forecast
current_day = start_date
day_number = 1
accumulated_overdue = current_overdue
zero_overdue_date = nil
had_overdue = current_overdue > 0

while current_day <= end_date
  # Get cards due on this specific day
  due_reviews = get_cards_due_on_day(db, crt, current_day)

  if current_day < Date.today
    # Past days - no historical simulation
    overdue_in_str  = "N/A"
    total_str       = "N/A"
    studied_str     = "N/A"
    overdue_out_str = "N/A"
    overdue_in      = nil
    overdue_out     = nil
  else
    overdue_in    = accumulated_overdue
    total_reviews = due_reviews + overdue_in

    # The 120 limit applies only to reviews (due + overdue). New cards are extra.
    if total_reviews > cards_studied_per_day
      studied     = cards_studied_per_day
      overdue_out = total_reviews - cards_studied_per_day
    else
      studied     = total_reviews
      overdue_out = 0
    end

    # Track first day accumulated overdue reaches zero
    if had_overdue && overdue_out == 0 && zero_overdue_date.nil?
      zero_overdue_date = current_day
    end

    accumulated_overdue = overdue_out

    overdue_in_str  = overdue_in.to_s
    total_str       = total_reviews.to_s
    studied_str     = studied.to_s
    overdue_out_str = overdue_out.to_s
  end

  # Show row if there are due reviews or accumulated overdue entering the day
  show_row = due_reviews > 0 || (current_day >= Date.today && overdue_in && overdue_in > 0)

  if show_row
    day_str  = day_number.to_s
    date_str = current_day.strftime('%Y-%m-%d')
    due_str  = due_reviews.to_s
    new_str  = new_cards_per_day.to_s

    if current_day == Date.today
      puts sprintf("%-5s | %-12s | %13s | %12s | %10s | %10s | %13s | %10s  ← TODAY",
                   day_str, date_str, due_str, overdue_in_str, total_str, studied_str, overdue_out_str, new_str)
    else
      puts sprintf("%-5s | %-12s | %13s | %12s | %10s | %10s | %13s | %10s",
                   day_str, date_str, due_str, overdue_in_str, total_str, studied_str, overdue_out_str, new_str)
    end
  end

  current_day += 1
  day_number += 1
end

puts "=" * 115
puts ""

# Summary statistics
total_days = (end_date - start_date).to_i + 1

puts "📊 SUMMARY STATISTICS"
puts "-" * 115
puts sprintf("  %-40s %10d days", "Total days in range:", total_days)
puts sprintf("  %-40s %10d cards", "Current overdue cards:", current_overdue)
puts sprintf("  %-40s %10d cards/day", "Daily review limit:", cards_studied_per_day)
puts sprintf("  %-40s %10d cards/day", "New cards per day (extra):", new_cards_per_day)

if zero_overdue_date
  days_to_zero = (zero_overdue_date - Date.today).to_i
  puts sprintf("  %-40s %10d days", "Days to zero overdue:", days_to_zero)
  puts sprintf("  %-40s %10s", "Projected zero date:", zero_overdue_date.strftime('%Y-%m-%d'))
  puts ""
  puts "  🎯 Overdue zerado em #{zero_overdue_date.strftime('%Y-%m-%d')}! 🎉"
elsif had_overdue
  puts ""
  puts "  ⚠️  Overdue não zera dentro do período informado."
end

puts ""
puts "=" * 115
puts ""

# Legend
puts "📖 LEGEND"
puts "-" * 115
puts "  Due Reviews: Cards agendados para revisão nesse dia (do banco do Anki)"
puts "  Overdue In:  Cards atrasados acumulados que entram nesse dia"
puts "  Total:       Due Reviews + Overdue In (total disponível para revisar, excluindo novos)"
puts "  Studied:     Cards efetivamente revisados = min(Total, #{cards_studied_per_day})"
puts "  New Overdue: Cards que não couberam no dia = max(0, Total - #{cards_studied_per_day})"
puts "  New Cards:   Novos cards aprendidos no dia (#{new_cards_per_day}/dia, NÃO contam no limite de #{cards_studied_per_day})"
puts ""
puts "Regra: O limite de #{cards_studied_per_day} reviews/dia se aplica apenas a Due Reviews + Overdue."
puts "       Os #{new_cards_per_day} novos cards são extras e se tornam reviews futuros."
puts ""
puts "=" * 115

# Close database
db.close

puts ""
puts "✓ Forecast completed successfully!"
puts ""
