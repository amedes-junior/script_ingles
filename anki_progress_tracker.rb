#!/usr/bin/env ruby
require 'sqlite3'
require 'date'

# Path to Anki database
DB_PATH = File.expand_path("~/Library/Application Support/Anki2/Usuário 1/collection.anki2")

# Study parameters
CARDS_STUDIED_PER_DAY = 100
NEW_CARDS_PER_DAY = 10
NET_PROGRESS_PER_DAY = CARDS_STUDIED_PER_DAY - NEW_CARDS_PER_DAY

# Target information
TARGET_OVERDUE = 0
INITIAL_OVERDUE = 5940
START_DATE = Date.parse('2025-10-18')
TARGET_DATE = Date.parse('2025-12-23')
TOTAL_DAYS_NEEDED = 66

# Open database connection
db = SQLite3::Database.new(DB_PATH)

# Get current total overdue cards
query = <<-SQL
  SELECT COUNT(*) as total_overdue
  FROM cards
  WHERE queue = 2
    AND type = 2
    AND due < (strftime('%s', 'now') - 1479276000) / 86400;
SQL

current_overdue = db.execute(query).first[0]
db.close

# Calculate progress
today = Date.today
days_elapsed = (today - START_DATE).to_i
days_remaining = (TARGET_DATE - today).to_i
cards_reduced = INITIAL_OVERDUE - current_overdue
expected_reduction = days_elapsed * NET_PROGRESS_PER_DAY
cards_remaining = current_overdue - TARGET_OVERDUE

# Calculate progress percentage
progress_percentage = ((INITIAL_OVERDUE - current_overdue).to_f / INITIAL_OVERDUE * 100).round(2)
expected_progress_percentage = ((expected_reduction).to_f / INITIAL_OVERDUE * 100).round(2)

# Determine if on track
on_track = current_overdue <= (INITIAL_OVERDUE - expected_reduction)
status = on_track ? "✓ ON TRACK" : "⚠ BEHIND SCHEDULE"
status_color = on_track ? "🟢" : "🔴"

# Calculate new target date based on current pace
if cards_reduced > 0 && days_elapsed > 0
  actual_rate = cards_reduced.to_f / days_elapsed
  days_needed_from_now = (current_overdue / actual_rate).ceil
  projected_completion = today + days_needed_from_now
else
  projected_completion = TARGET_DATE
end

# Display header
puts "=" * 80
puts "                    ANKI PROGRESS TRACKER"
puts "=" * 80
puts ""

# Current status
puts "📊 CURRENT STATUS (#{today.strftime('%Y-%m-%d')})"
puts "-" * 80
puts "  Current overdue cards:        #{current_overdue.to_s.rjust(10)} cards"
puts "  Initial overdue cards:        #{INITIAL_OVERDUE.to_s.rjust(10)} cards"
puts "  Cards reduced so far:         #{cards_reduced.to_s.rjust(10)} cards"
puts "  Cards remaining:              #{cards_remaining.to_s.rjust(10)} cards"
puts ""

# Progress bar
bar_width = 50
filled = (progress_percentage / 100.0 * bar_width).round
empty = bar_width - filled
progress_bar = "█" * filled + "░" * empty
puts "  Progress: [#{progress_bar}] #{progress_percentage}%"
puts ""

# Time tracking
puts "📅 TIME TRACKING"
puts "-" * 80
puts "  Start date:                   #{START_DATE.strftime('%Y-%m-%d (%A)')}"
puts "  Target date:                  #{TARGET_DATE.strftime('%Y-%m-%d (%A)')}"
puts "  Today:                        #{today.strftime('%Y-%m-%d (%A)')}"
puts "  Days elapsed:                 #{days_elapsed.to_s.rjust(10)} / #{TOTAL_DAYS_NEEDED} days"
puts "  Days remaining:               #{days_remaining.to_s.rjust(10)} days"
puts ""

# Performance analysis
puts "📈 PERFORMANCE ANALYSIS"
puts "-" * 80
puts "  Expected reduction:           #{expected_reduction.to_s.rjust(10)} cards (#{expected_progress_percentage}%)"
puts "  Actual reduction:             #{cards_reduced.to_s.rjust(10)} cards (#{progress_percentage}%)"

if days_elapsed > 0
  actual_rate = (cards_reduced.to_f / days_elapsed).round(2)
  difference = cards_reduced - expected_reduction

  puts "  Target pace:                  #{NET_PROGRESS_PER_DAY.to_s.rjust(10)} cards/day"
  puts "  Actual pace:                  #{actual_rate.to_s.rjust(10)} cards/day"
  puts ""

  if difference >= 0
    puts "  #{status_color} You are #{difference.abs} cards AHEAD of schedule! #{status}"
  else
    puts "  #{status_color} You are #{difference.abs} cards BEHIND schedule. #{status}"
  end
  puts ""

  # Projected completion
  puts "  Projected completion date:    #{projected_completion.strftime('%Y-%m-%d (%A)')}"

  if projected_completion <= TARGET_DATE
    days_early = (TARGET_DATE - projected_completion).to_i
    puts "  Expected to finish:           #{days_early} days EARLY! 🎉"
  else
    days_late = (projected_completion - TARGET_DATE).to_i
    puts "  Expected to finish:           #{days_late} days LATE ⚠️"
  end
end

puts ""

# Daily goal
puts "🎯 TODAY'S GOAL"
puts "-" * 80
puts "  Review cards needed:          #{CARDS_STUDIED_PER_DAY.to_s.rjust(10)} cards"
puts "  New cards to learn:           #{NEW_CARDS_PER_DAY.to_s.rjust(10)} cards"
puts "  Net reduction target:         #{NET_PROGRESS_PER_DAY.to_s.rjust(10)} cards"
puts ""

# Motivation message
if days_remaining > 0
  cards_per_day_needed = (cards_remaining.to_f / days_remaining).ceil

  puts "💪 MOTIVATION"
  puts "-" * 80

  if on_track
    puts "  Great job! Keep up the excellent work!"
    puts "  You only need to maintain #{cards_per_day_needed} cards/day to reach your goal."
  else
    puts "  Don't give up! You can still make it!"
    puts "  To get back on track, aim for #{cards_per_day_needed} cards/day."
  end

  puts ""
  puts "  Remember: Consistency is key! 🔑"
  puts "  Every card you review brings you closer to your goal! 🌟"
end

puts ""
puts "=" * 80
puts ""

# Day-by-day progress
puts "📅 DAY-BY-DAY PROGRESS"
puts "=" * 80
puts ""
puts sprintf("%-5s | %-12s | %-15s | %-15s | %s",
             "Day", "Date", "Expected", "Projected", "Status")
puts "-" * 80

# Show progress from start date to target date
current_day = START_DATE
day_number = 0

while current_day <= TARGET_DATE
  day_number += 1

  # Calculate expected overdue for this day
  expected_overdue = [INITIAL_OVERDUE - (day_number * NET_PROGRESS_PER_DAY), 0].max

  # Determine if this is a past, present, or future day
  if current_day < today
    # Past day - use "No data" since we don't have historical tracking
    projected_overdue = "No data"
    status_icon = "📊"
  elsif current_day == today
    # Today - show actual current overdue
    projected_overdue = current_overdue.to_s
    actual_vs_expected = current_overdue - expected_overdue

    if actual_vs_expected <= 0
      status_icon = "🟢 On track"
    elsif actual_vs_expected <= 100
      status_icon = "🟡 Slightly behind"
    else
      status_icon = "🔴 Behind"
    end
  else
    # Future day - project based on current pace
    if days_elapsed > 0 && cards_reduced > 0
      actual_rate = cards_reduced.to_f / days_elapsed
      days_from_now = (current_day - today).to_i
      projected_overdue = [current_overdue - (days_from_now * actual_rate).round, 0].max.to_s
    else
      projected_overdue = expected_overdue.to_s
    end
    status_icon = "📈 Projected"
  end

  # Highlight today
  if current_day == today
    puts sprintf("%-5s | %-12s | %15s | %15s | %s  ← TODAY",
                 day_number.to_s,
                 current_day.strftime('%Y-%m-%d'),
                 "#{expected_overdue} cards",
                 "#{projected_overdue} cards",
                 status_icon)
  else
    puts sprintf("%-5s | %-12s | %15s | %15s | %s",
                 day_number.to_s,
                 current_day.strftime('%Y-%m-%d'),
                 "#{expected_overdue} cards",
                 "#{projected_overdue} cards",
                 status_icon)
  end

  current_day += 1
end

puts "=" * 80
puts ""
puts "Legend:"
puts "  Expected: Cards remaining if following #{NET_PROGRESS_PER_DAY} cards/day pace"
puts "  Projected: Estimated cards based on your actual pace"
puts "  🟢 On track | 🟡 Slightly behind | 🔴 Behind | 📈 Projected future"
puts ""

# Summary statistics
puts "=" * 80
puts "📋 QUICK SUMMARY"
puts "-" * 80
puts sprintf("  %-30s %10d cards", "Overdue cards:", current_overdue)
puts sprintf("  %-30s %10d%%", "Progress:", progress_percentage.to_i)
puts sprintf("  %-30s %10d days", "Days remaining:", [days_remaining, 0].max)
puts sprintf("  %-30s %10s", "Status:", on_track ? "On Track ✓" : "Behind ⚠")
puts "=" * 80
