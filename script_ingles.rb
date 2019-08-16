require "fuzzystringmatch"

def clear_files
  %x(rm list01.txt; rm list02.txt; rm list03.txt; rm list04.txt; rm output.txt)
  %x(rm *.mp3)
end

def unzip
  %x(ls *.zip > file_list.txt)
  file_list = File.open("file_list.txt", "r")
  file_list.each do |file|
    file.gsub!(" ", "\\ ")
    system("unzip -o #{file}")
  end
  file_list.close

  %x(ls *.mp3 > file_list.txt)
  file_list = File.open("file_list.txt", "r")
  file_list.each do |file|
    puts "Renomeando arquivo #{file.strip} "
    file = file.gsub('$', '\$')
    %x(mv "#{file.strip}" #{file.strip.gsub('\'', '').gsub(' ', '-').gsub(';', '').gsub('’', '').gsub('?', '').gsub('‘', '').gsub('—','-')})
  end
  file_list.close
  system("cp *.mp3 '/home/aecj/.local/share/Anki2/Usuário 1/collection.media/'")
  %x(rm *.zip)
end


def convert

  %x(grep '^$' list00.txt -v > list01.txt)
  %x(grep '^00' list01.txt -v > list02.txt)
  %x(grep '^Audio' list02.txt -v > list03.txt)
  %x(grep '^Use Up/Down Arrow' list03.txt -v > list04.txt)

  %x(rm list01.txt; rm list02.txt; rm list03.txt)
end

def search_mp3_file (arr_mp3, str_search)
  jarow = FuzzyStringMatch::JaroWinkler.create( :native )
  x = 0
  f = ""

  arr_mp3.each do |file|
    y = jarow.getDistance(file.gsub('-',' '),str_search )
    if y > x
      #puts "x = #{x} y = #{y} ===> Array File = #{file.gsub('-',' ')} x File = #{str_search}"
      f = file
      x = y
    end
  end
  puts "#{f} - #{x*100}%"
  return f
end


def work_file

  # Arr mp3 Files
  arr_mp3 = Array.new
  %x(ls *.mp3 > file_list.txt)
  file_list = File.open("file_list.txt", "r")
  file_list.each do |file|
    arr_mp3 << file.strip
  end
  file_list.close
  #

  file_text = File.open("list04.txt", "r")
  file_output = File.open("output.txt", "w")
  mp3_file = ""
  seq = 1
  line = 0
  header = ""
  line_anki = ""
  file_text.each do |file|
    case line
    when 0
      header = file.strip.gsub(";",",")
      line = 1
    else
      if line % 2 == 0
        line_anki << file.strip.gsub(";",",") + ";"
        #mp3_file = seq.to_s + " - " + file.strip.gsub(";",",") + "mp3"
        #mp3_file = mp3_file.gsub(' ', '-').gsub('’', '').gsub('\'', '').gsub('?', '.').gsub('‘', '').gsub('—','-')
        mp3_file = search_mp3_file(arr_mp3, file)
        #puts "====> #{mp3_file}"
      else
        if arr_mp3.include? mp3_file
          puts "#{mp3_file} ======> OK"
        else
          puts "#{mp3_file} ======> Error"
        end
        line_anki << file.strip.gsub(";",",") + "<br/><br/><br/>" + header + ";[sound:#{mp3_file}]"
        seq += 1
        file_output.puts line_anki
        line_anki = ""
      end
    end
    line += 1
  end

  file_text.close
  file_output.close


end

def prepare_file
  file = File.open("list00.txt", "r")
  file_out = File.open("list00_.txt", "w")
  str_match = ""

  file.each do |line|
    if line.match(/^[1-9].–/)
      puts line
      str_match << "<br/><br/>#{line.strip}"
    else
      file_out.puts line
    end
  end
  file.close
  file_out.close

  file = File.open("list00_.txt", "r")
  file_out = File.open("list00__.txt", "w")
  cont = 0
  file.each do |line|
    if cont == 1
      file_out.puts str_match
    else
      file_out.puts line
    end
    cont += 1
  end
  file.close
  file_out.close

end

cont = %x( cat list00.txt | grep '^[1-9].–' | wc -l)
if cont.to_i > 0
  prepare_file
  %x(rm list00_.txt list00.txt)
  %x(mv list00__.txt list00.txt)
  puts "Arquivo foi manipulado com sucesso. Favor executar o script novamente"
else
  clear_files
  unzip
  convert
  work_file
end

