#!/usr/bin/env ruby
require 'date'
require 'sqlite3'

# Configurações
ANKI_DB = "/Users/aecj/Library/Application Support/Anki2/Usuário 1/collection.anki2"
CARDS_PER_DAY = 120       # Cards de revisão por dia (atrasados + que vencem)
NEW_CARDS_PER_DAY = 5     # Novos cards adicionais (MAIS 10, totalizando 110/dia)

def get_overdue_cards
  db = SQLite3::Database.new(ANKI_DB)
  result = db.execute("
    SELECT COUNT(*) as total_overdue
    FROM cards
    WHERE queue = 2
    AND type = 2
    AND due < (strftime('%s', 'now') - 1479276000) / 86400
  ")
  db.close
  result[0][0]
end

def get_cards_due_per_day(days_ahead)
  db = SQLite3::Database.new(ANKI_DB)

  # Pegar data de hoje como número de dias desde epoch do Anki
  today_due = db.execute("SELECT CAST((strftime('%s', 'now') - 1479276000) / 86400 AS INTEGER)")[0][0]

  results = db.execute("
    SELECT date(1479276000 + (due * 86400), 'unixepoch') as due_date,
           COUNT(*) as cards_due
    FROM cards
    WHERE queue = 2
    AND type = 2
    AND due >= #{today_due}
    AND due <= #{today_due + days_ahead}
    GROUP BY due
    ORDER BY due
  ")
  db.close

  # Converter para hash {data => quantidade}
  cards_by_date = {}
  results.each do |row|
    cards_by_date[row[0]] = row[1]
  end
  cards_by_date
end

def calculate_zero_date(overdue_cards)
  # Simulação dia a dia para calcular quando vai zerar
  cards_by_date = get_cards_due_per_day(2000)

  current_overdue = overdue_cards
  current_date = Date.today
  days = 0
  new_cards_from_yesterday = 0

  loop do
    # Cards que vencem hoje (do banco)
    date_str = current_date.strftime('%Y-%m-%d')
    cards_due_from_bank = cards_by_date[date_str] || 0

    # Total para zerar hoje
    total_to_clear = current_overdue + cards_due_from_bank + new_cards_from_yesterday

    # Estudar 100 cards
    cards_studied = [CARDS_PER_DAY, total_to_clear].min

    # Restantes
    current_overdue = total_to_clear - cards_studied

    # 10 novos estudados hoje vencerão amanhã
    new_cards_from_yesterday = NEW_CARDS_PER_DAY

    days += 1
    current_date += 1

    break if current_overdue <= 0 || days > 5000
  end

  [Date.today + days - 1, days]
end

def print_summary(overdue_cards, zero_date, days_needed)
  puts "=" * 80
  puts "ANKI - CALCULADORA DE DATA PARA ZERAR CARDS ATRASADOS"
  puts "=" * 80
  puts ""
  puts "📊 Situação Atual:"
  puts "  • Total de cards atrasados: #{overdue_cards}"
  puts "  • Data de hoje: #{Date.today.strftime('%d/%m/%Y (%A)')}"
  puts ""
  puts "📚 Seu Ritmo de Estudo:"
  puts "  • Cards de revisão por dia: #{CARDS_PER_DAY} (atrasados + que vencem)"
  puts "  • Novos cards por dia: #{NEW_CARDS_PER_DAY} (adicionais)"
  puts "  • Total estudado por dia: #{CARDS_PER_DAY + NEW_CARDS_PER_DAY} cards"
  puts ""
  puts "🎯 Projeção:"
  puts "  • Dias necessários: #{days_needed} dias"
  puts "  • Data para zerar: #{zero_date.strftime('%d/%m/%Y (%A)')}"
  puts ""
  puts "=" * 80
  puts ""
  puts "💡 Explicação:"
  puts "Você estuda #{CARDS_PER_DAY} cards de revisão por dia (atrasados + vencendo hoje)."
  puts "Se houver mais de #{CARDS_PER_DAY} cards, o excedente vira atrasado para o próximo dia."
  puts ""
  puts "Além disso, você estuda #{NEW_CARDS_PER_DAY} cards completamente novos por dia,"
  puts "que vencerão amanhã e entrarão na contagem de revisão."
  puts ""
  puts "O cálculo considera os cards que vencerão cada dia para projetar"
  puts "quando você zerará os atrasados."
  puts "=" * 80
end

def print_daily_projection(overdue_cards, days_needed)
  puts ""
  puts "📅 PROJEÇÃO DIÁRIA"
  puts "=" * 100

  # Buscar cards que vencem por dia
  cards_by_date = get_cards_due_per_day(2000)

  current_overdue = overdue_cards
  current_date = Date.today
  day = 0
  new_cards_from_yesterday = 0
  max_overdue = overdue_cards

  puts ""
  puts sprintf("%-5s %-12s %-10s %-12s %-10s %-12s %-10s %-10s %-10s",
               "Dia", "Data", "Atrasados", "Vencem Hoje", "Novos(10)", "Total", "Estudados", "Novos Hj", "Restantes")
  puts "-" * 100

  loop do
    # Cards atrasados do início do dia
    cards_at_start = current_overdue

    # Cards que vencem hoje (do banco Anki)
    date_str = current_date.strftime('%Y-%m-%d')
    cards_due_from_bank = cards_by_date[date_str] || 0

    # Novos cards do dia anterior que vencem hoje
    new_cards_due = new_cards_from_yesterday

    # Total de cards para zerar hoje
    total_to_clear = cards_at_start + cards_due_from_bank + new_cards_due

    # Cards que serão estudados (máximo 100 dos cards antigos)
    cards_studied = [CARDS_PER_DAY, total_to_clear].min

    # Novos cards estudados hoje (10 - sempre estudados além dos 100)
    new_cards_today = NEW_CARDS_PER_DAY

    # Restantes = total não estudado
    current_overdue = total_to_clear - cards_studied

    # Atualizar máximo de atrasados
    max_overdue = [max_overdue, current_overdue].max

    # Os 10 novos estudados hoje vencerão amanhã
    new_cards_from_yesterday = new_cards_today

    day_label = day == 0 ? "Hoje" : "+#{day}"
    puts sprintf("%-5s %-12s %-10s %-12s %-10s %-12s %-10s %-10s %-10s",
                 day_label,
                 current_date.strftime('%d/%m/%y'),
                 cards_at_start,
                 cards_due_from_bank,
                 new_cards_due,
                 total_to_clear,
                 cards_studied,
                 new_cards_today,
                 current_overdue)

    current_date += 1
    day += 1

    # Para quando zerar ou atingir limite de dias
    break if current_overdue <= 0 || day > days_needed + 50
  end

  puts "=" * 100
  puts ""
  puts "📊 Resumo:"
  puts "  • Total de dias: #{day}"
  puts "  • Data final: #{(Date.today + day - 1).strftime('%d/%m/%Y (%A)')}"
  if max_overdue > overdue_cards
    puts "  • Pico de atrasados: #{max_overdue} cards"
  end
  puts ""
  puts "💡 Legenda:"
  puts "  • Atrasados: Cards que já estavam atrasados de dias anteriores"
  puts "  • Vencem Hoje: Cards programados no banco Anki para vencer hoje"
  puts "  • Novos(5): 5 novos cards do dia anterior que vencem hoje"
  puts "  • Total: Atrasados + Vencem Hoje + Novos(10) = Total de cards para zerar"
  puts "  • Estudados: 120 cards antigos estudados (do Total)"
  puts "  • Novos Hj: 5 novos cards estudados hoje (vão vencer amanhã)"
  puts "  • Restantes: Total - Estudados = Atrasados para o próximo dia"
  puts ""
  puts "  📝 Total estudado por dia: #{CARDS_PER_DAY} antigos + #{NEW_CARDS_PER_DAY} novos = #{CARDS_PER_DAY + NEW_CARDS_PER_DAY} cards"
  puts "=" * 100
end

def print_weekly_projection(overdue_cards, days_needed)
  puts ""
  puts "📅 PROJEÇÃO SEMANAL"
  puts "=" * 80

  current_overdue = overdue_cards
  current_date = Date.today
  week = 1

  while current_overdue > 0 && week <= 12
    week_start = current_date
    week_end = current_date + 6

    cards_at_start = current_overdue
    cards_reduced = [NET_PROGRESS * 7, current_overdue].min
    current_overdue -= cards_reduced
    cards_at_end = current_overdue

    puts ""
    puts "Semana #{week}: #{week_start.strftime('%d/%m')} - #{week_end.strftime('%d/%m/%Y')}"
    puts "  Início: #{cards_at_start} cards"
    puts "  Redução: -#{cards_reduced} cards"
    puts "  Final: #{cards_at_end} cards"

    current_date += 7
    week += 1
  end

  puts "=" * 80
end

# Programa principal
puts ""
overdue_cards = get_overdue_cards
zero_date, days_needed = calculate_zero_date(overdue_cards)

print_summary(overdue_cards, zero_date, days_needed)

# Menu de opções
puts ""
puts "📋 OPÇÕES DE PROJEÇÃO:"
puts "  1 - Projeção diária (dia a dia)"
puts "  2 - Projeção semanal (semana a semana)"
puts "  3 - Ambas"
puts "  0 - Nenhuma"
puts ""
print "Escolha uma opção (0-3): "

response = gets.chomp

case response
when '1'
  print_daily_projection(overdue_cards, days_needed)
when '2'
  print_weekly_projection(overdue_cards, days_needed)
when '3'
  print_daily_projection(overdue_cards, days_needed)
  print_weekly_projection(overdue_cards, days_needed)
end

puts ""
puts "✅ Mantenha o ritmo e você zerará em #{zero_date.strftime('%d/%m/%Y')}!"
puts ""
