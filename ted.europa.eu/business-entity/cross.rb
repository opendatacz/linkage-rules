countries = [
  #{code: "no-address", count: 129668},
  {code: "no-country", count: 76458},
].sort{|i| i.count}

puts 'Starting'


options = []

alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
alphabet = 'A'
simple_condition = 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "LL"))'
alphabet.split('').each do |letter|
  options << { :ident => letter, :cond => simple_condition.gsub(/LL/, letter) }
end

options << { :ident => 'less-than-A', :cond => 'schema:legalName ?name . BIND(SUBSTR(CONCAT(UCASE(STR(?name)), "  "), 1, 1) AS ?l) FILTER(?l &lt; "A")' }
options << { :ident => 'more-than-Z', :cond => 'schema:legalName ?name . BIND(SUBSTR(CONCAT(UCASE(STR(?name)), "  "), 1, 1) AS ?l) FILTER(?l &gt; "Z")' }

countries.each do |country|
  puts "Country: #{country[:code]}"
  blocks = 5000

  options.each do |option|
    ident = option[:ident]

    puts "Option: #{ident}"
    template = File.open("#{country[:code]}-cross.xml", "r")
    config = template.read
    template.close

    config = config.gsub(/XX/, country[:code]).gsub(/BB/, blocks.to_s).gsub(/LL/, option[:cond]).gsub(/PP/, ident)
    config_path = "config-#{country[:code]}-#{ident}.xml"
    file = File.open(config_path, "w")
    file.write config
    file.close

    puts "Wrote config for #{country[:code]}-#{ident}"
    start = Time.now
    puts %x{"C:\\Program Files\\Java\\jre7\\bin\\java.exe" -Xmx5000m -DconfigFile=#{config_path} -jar "c:\\Program Files\\Silk Workbench\\commandline\\silk.jar\" 2> log-#{country[:code]}-#{ident}.log}
    endt = Time.now
    diff = endt - start
    puts "Finished #{country[:code]}-#{ident} in #{diff} secs"
  end
end

puts 'Finished'
