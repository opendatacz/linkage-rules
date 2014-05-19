prefix = ''
(0..9).each do |digit|
  ident = "#{prefix}#{digit}"
  template = File.open("config-cz-ico--cz-ico.xml", "r")
  config = template.read
  template.close

  config = config.gsub(/XX/, prefix.to_s + digit.to_s)
  config_path = "config-cz-ico--cz-ico-#{ident}.xml"
  file = File.open(config_path, "w")
  file.write config
  file.close
  
  puts "Wrote config for #{ident}"
  start = Time.now
  %x{"C:\\Program Files\\Java\\jre7\\bin\\java.exe" -Xmx5500m -DconfigFile=#{config_path} -jar "c:\\Program Files\\Silk Workbench\\commandline\\silk.jar\" 2> log-#{ident}.log}
  endt = Time.now
  diff = endt - start
  puts "Finished #{ident} in #{diff} secs"
end