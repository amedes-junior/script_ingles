require "fuzzystringmatch"
require "byebug"

def clear_files
  #%x(rm list01.txt; rm list02.txt; rm list03.txt; rm list04.txt; rm output.txt)
  %x(rm *.mp3; rm *.pdf)
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
  #%x(grep '^$' list00.txt -v > list01.txt)

  %x(grep '^00' list00.txt -v > list00_1.txt)
  %x(grep '^Audio' list00_1.txt -v > list00_2.txt)
  %x(grep '^Use Up/Down Arrow' list00_2.txt -v > list00_3.txt)

  %x(rm list00_1.txt; rm list00_2.txt; rm list00.txt)

  %x(mv list00_3.txt list00.txt)
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
  puts "#{f} - #{x*100}% - #{str_search}"
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
  file = File.open("list01.txt", "r")
  file_out = File.open("list01_.txt", "w")
  str_match = ""

  file.each do |line|
    if line.match(/^[1-9].–/)
      #puts line
      str_match << "<br/><br/>#{line.strip}"
    else
      file_out.puts line.strip
    end
  end
  file.close
  file_out.close


  file = File.open("list01_.txt", "r")
  file_out = File.open("list01__.txt", "w")
  cont = 1
  file.each do |line|
    if cont == 1
      file_out.puts "#{line.strip} - #{str_match.strip}"
    else
      file_out.puts line
    end
    cont += 1
  end
  file.close
  file_out.close

end

def prepare_cab
  file = File.open("list00.txt", "r")
  file_out = File.open("list01.txt", "w")
  str_match = ""

  cab = true

  file.each do |line|
    if line.match("###")
      cab = false
      file_out.puts str_match
    else
      str_match << "#{line.strip}<br/>"
    end
    unless cab
      file_out.puts line
    end
  end
  file.close
  file_out.close
end

def prepare_lines
  first_blank = false
  arq = ""
  a_anki = Array.new
  file = File.open("list01.txt", "r")
  file_out = File.open("list02.txt", "w")
  file.each do |line|
    #byebug
    arq << line
    if !first_blank && line.length == 1
      first_blank = true
      file_out.puts arq
    end
    #
    if first_blank
      if line.length == 1
        if a_anki.size > 0
          a_anki.each {|e| file_out.puts e}
          file_out.puts
          a_anki = []
        end
      else
        a_anki.size == 0 || a_anki.size == 1 ? a_anki << line.strip : a_anki[1] += line.strip
      end
    end
  end
  a_anki.each {|e| file_out.puts e}
  file_out.puts
  file.close
  file_out.close
end

def wipe_line
  %x(grep '^###' list02.txt -v > list03.txt)
  %x(grep '^$' list03.txt -v > list04.txt)
end

########################################################################

convert
prepare_cab
cont = %x( cat list01.txt | grep '^[1-9].–' | wc -l)
if cont.to_i > 0
  prepare_file
  %x(rm list01_.txt)
  %x(mv list01__.txt list01.txt)
  puts "Arquivo foi manipulado com sucesso."
end
prepare_lines

wipe_line

clear_files
unzip
work_file



