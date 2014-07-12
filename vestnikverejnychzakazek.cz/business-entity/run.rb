# encoding=utf-8

# Config
config = {
  :source => {
    :endpoint => 'http://lod2-dev.vse.cz:8890/sparql',
    :graph => 'http://linked.opendata.cz/resource/dataset/vestnikverejnychzakazek.cz',
  },
  :output => {
    :endpoint => 'http://lod2-dev.vse.cz:8890/sparql-auth',
    :login => 'login',
    :password => 'pass',
    :graph => 'http://linked.opendata.cz/resource/dataset/vestnikverejnychzakazek.cz/links'
  },
  :run => {
    :java => 'C:\\Program Files\\Java\\jre7\\bin\\java.exe',
    :memory => '5500m',
    :silk => 'c:\\Program Files\\Silk Workbench\\commandline\\silk.jar',
    :cores => '1-3' # in taskset syntax
  }
}

GENERATED_RULES = 'generated-rules'
Dir.mkdir GENERATED_RULES unless File.directory? GENERATED_RULES
def get_files(dir)
  Dir.entries(dir).select { |f| !File.directory? f }
end
def write_generated_rules(config, content)
  target = File.open("#{GENERATED_RULES}/#{config}", 'w')
  target.write content
  target.close
  puts "Wrote config #{config}"
end
def generate_rules_from_template(rules, restrictions)
  rules.each do |rule|
    source = File.open("template-rules/#{rule}.xml", 'r')
    template = source.read
    restrictions.each do |restriction|
      config = template.gsub /RESTR/, restriction[:restriction]
      write_generated_rules "#{rule}-#{restriction[:name]}.xml", config
    end
    source.close
  end
end


puts 'Preparing fixed rules'
dir = 'fixed-rules'
get_files(dir).each do |file|
  source = File.open("#{dir}/#{file}", 'r')
  write_generated_rules file, source.read
  source.close
end

puts 'Preparing rules based only on name comparison'
alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
restrictions = alphabet.split('').map do |letter|
  {
    :name => letter,
    :restriction => " BIND(SUBSTR(CONCAT(UCASE(STR(?name)), \"    \"), 1, 1) AS ?l) FILTER(?l = \"#{letter}\")"
  }
end
restrictions << {
  :name => 'less-than-A',
  :restriction => ' BIND(SUBSTR(CONCAT(UCASE(STR(?name)), "    "), 1, 1) AS ?l) FILTER(?l &lt; "A")' ,
}
restrictions << {
  :name => 'more-than-Z',
  :restriction => ' BIND(SUBSTR(CONCAT(UCASE(STR(?name)), "    "), 1, 1) AS ?l) FILTER(?l &gt; "Z")' ,
}
rules = %w(config-cz-name--cz-name config-cz-ico--cz-name)
generate_rules_from_template rules, restrictions


puts 'Preparing rules based only on IČ comparison'
rules = %w(config-cz-ico--cz-ico)
restrictions = (0..9).map do |digit|
  {
    :name => digit,
    :restriction => "FILTER(STRSTARTS(?not, \"#{digit}\"))"
  }
end
generate_rules_from_template rules, restrictions


output = <<-XML
  <Param name="uri" value="#{config[:output][:endpoint]}"/>
  <Param name="login" value="#{config[:output][:login]}"/>
  <Param name="password" value="#{config[:output][:password]}"/>
  <Param name="graphUri" value="#{config[:output][:graph]}"/>
XML

puts 'Adding shared information about source and output'
get_files(GENERATED_RULES).each do |file|
  rule = File.open("#{GENERATED_RULES}/#{file}", 'r+')
  rule_text = rule.read
  rule_text = rule_text.gsub /SOURCE_ENDPOINT/, config[:source][:endpoint]
  rule_text = rule_text.gsub /SOURCE_GRAPH/, config[:source][:graph]
  rule_text = rule_text.gsub /OUTPUT/, output
  rule.rewind
  rule.write rule_text
  rule.close
end

get_files(GENERATED_RULES).each do |file|
  start = Time.now
  %x{"#{config[:run][:java]}" -Xmx#{config[:run][:memory]} -DconfigFile=#{GENERATED_RULES}/#{file} -jar "#{config[:run][:silk]}" 2> logs/log-#{file}.log}
  puts "Finished #{file} in #{Time.now - start} secs"
end