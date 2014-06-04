
bases = [
  { :ident => 'RO-P', :country => 'RO', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "P"))' },
  { :ident => 'RO-S', :country => 'RO', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "S"))' },
  { :ident => 'IT-A', :country => 'IT', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "A"))' },
  { :ident => 'IT-C', :country => 'IT', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "C"))' },
  { :ident => 'FR-C', :country => 'FR', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "C"))' },
  { :ident => 'PL-A', :country => 'PL', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "A"))' },
  { :ident => 'PL-B', :country => 'PL', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "B"))' },
  { :ident => 'PL-C', :country => 'PL', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "C"))' },
  { :ident => 'PL-D', :country => 'PL', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "D"))' },
  { :ident => 'PL-F', :country => 'PL', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "F"))' },
  { :ident => 'PL-G', :country => 'PL', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "G"))' },
  { :ident => 'PL-K', :country => 'PL', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "K"))' },
  { :ident => 'PL-P', :country => 'PL', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "P"))' },
  { :ident => 'PL-S', :country => 'PL', :cond => 'schema:legalName ?name . FILTER(STRSTARTS(UCASE(STR(?name)), "S"))' },
]

options = []
bases.each do |base|
  alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  #alphabet = 'DEFGHIJKLMNOPQRSTUVWXYZ'
  simple_condition = ' BIND(SUBSTR(CONCAT(UCASE(STR(?name)), "    "), 4, 1) AS ?l) FILTER(?l = "LL")'
  alphabet.split('').each do |letter|
    options << { 
      :ident => base[:ident] + '-' + letter, 
      :cond => base[:cond] + simple_condition.gsub(/LL/, letter) ,
      :country => base[:country]
    }
  end
  options << { 
    :ident => base[:ident] + '-less-than-A', 
    :cond => base[:cond] + ' BIND(SUBSTR(CONCAT(UCASE(STR(?name)), "    "), 4, 1) AS ?l) FILTER(?l &lt; "A")' ,
    :country => base[:country]
  }
  options << { 
    :ident => base[:ident] + '-more-than-Z', 
    :cond => base[:cond] + ' BIND(SUBSTR(CONCAT(UCASE(STR(?name)), "    "), 4, 1) AS ?l) FILTER(?l &gt; "Z")' ,
    :country => base[:country]
  }
end

options.each do |option|
  ident = option[:ident]

  puts "Option: #{ident}"
  template = File.open("config-part.xml", "r")
  config = template.read
  template.close

  config = config.gsub(/XX/, option[:country]).gsub(/BB/, 2000.to_s).gsub(/LL/, option[:cond]).gsub(/PP/, ident)
  config_path = "config-#{option[:country]}-#{ident}.xml"
  file = File.open(config_path, "w")
  file.write config
  file.close

  puts "Wrote config for #{ident}"
  start = Time.now
  puts %x{"C:\\Program Files\\Java\\jre7\\bin\\java.exe" -Xmx4000m -DconfigFile=#{config_path} -jar "c:\\Program Files\\Silk Workbench\\commandline\\silk.jar\" 2> log-#{ident}.log}
  endt = Time.now
  diff = endt - start
  puts "Finished #{ident} in #{diff} secs"
end