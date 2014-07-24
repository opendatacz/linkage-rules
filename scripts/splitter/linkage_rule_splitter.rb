require "rubygems"

require "fileutils"
require "json"
require "mustache"
require "nokogiri"
require "securerandom"
require "sparql/client"
require "thor"

class LinkageRuleSplitter < Thor
  def self.exit_on_failure?
    true
  end

  no_commands do
    # Extracts configuration options from the provided linkage rule.
    # 
    # @return [Hash] Hash-map with configuration
    #
    def extract_config()
      # Extract prefixes for SPARQL queries
      prefixes = @rule.xpath("/Silk/Prefixes/Prefix").map do |prefix|
        "PREFIX #{prefix.xpath("@id")}: <#{prefix.xpath("@namespace")}>"
      end.join("\n")
     
      # Extract data sources
      data_sources = @rule.xpath("/Silk/DataSources/DataSource").map do |data_source|
        source_id = data_source.xpath("@id").first.value
        {
          :source_id => source_id,
          :sparql_endpoint => SPARQL::Client.new(
            data_source.xpath("Param[@name='endpointURI']/@value").first.value
          ),
          :named_graph => data_source.xpath("Param[@name='graph']/@value").first.value,
          :source_restriction => @rule.xpath(
            "Silk/Interlinks/Interlink/SourceDataset[@dataSource='#{source_id}']/RestrictTo"
          ).first,
          :target_restriction => @rule.xpath(
            "Silk/Interlinks/Interlink/TargetDataset[@dataSource='#{source_id}']/RestrictTo"
          ).first
        }
      end.first # FIXME: Works for a single data source ATM.
    
      output_path = @rule.xpath("/Silk/Outputs/Output/Param[@name='file']/@value").first

      {
        :data_sources => data_sources,
        :output_path => output_path,
        :prefixes => prefixes,
      }
    end

    # Render restriction pattern based on static `restriction_text`. Restricts bindings
    # of `restriction_variable` by applying available values from `restriction_pattern`.
    # Generates FILTER NOT EXISTS if `restriction_pattern` contains a nil value.
    #
    # @param restriction_text [String]         Static restriction text
    # @param restriction_variable [String]     SPARQL query variable to be restricted
    # @param restriction_pattern [Array<Hash>] Restriction on property path and value
    # @return [String]                         Rendered SPARQL graph pattern
    #
    def get_restriction_pattern(restriction_text, restriction_variable, restriction_pattern)
      Mustache.render("
        {{{restriction_text}}}
        {{#restriction_pattern}}
          {{#value}}
            ?{{restriction_variable}} {{property_path}} {{{value}}} .
          {{/value}}
          {{^value}}
            FILTER NOT EXISTS {
              ?{{restriction_variable}} {{property_path}} [] .
            }
          {{/value}}
        {{/restriction_pattern}}",
        :restriction_pattern => restriction_pattern,
        :restriction_text => restriction_text,
        :restriction_variable => restriction_variable)
    end

    # Create linkage rules for each cluster split by values of `property_paths`.
    # Save the resulting rules into the directory `output_dir`.
    # Raise an exception if the combination of `property_paths` values yields more
    # than maximum number of rules (`max_rules`).
    #
    # @param property_paths [Array<String>] SPARQL 1.1 property paths to use in clustering
    # @param output_dir [String]            Path to output directory
    # @param max_rules [Integer]            Limit to maximum number of generated rules
    # @return nil                           Side-effecting method saving output to files.
    # @raise [RuntimeError, Thor::Error] 
    #
    def get_restrictions(property_paths, output_dir, max_rules)
      raise "Directory #{output_dir} doesn't exist!" unless File.exists? output_dir

      property_paths = property_paths.each_with_index.map do |property_path, i|
        {:object_variable => "o#{i + 1}",
         :property_path => property_path}
      end

      sparql_endpoint = @config[:data_sources][:sparql_endpoint]
      named_graph = @config[:data_sources][:named_graph]
      prefixes = @config[:prefixes]
      source_restriction = @config[:data_sources][:source_restriction]
      source_restriction_variable = source_restriction.xpath("../@var").first.value
      target_restriction = @config[:data_sources][:target_restriction] 
      target_restriction_variable = target_restriction.xpath("../@var").first.value

      graph_pattern = Mustache.render("
        SELECT DISTINCT 
        {{#property_paths}}
        ?{{object_variable}}
        {{/property_paths}}
        WHERE {
          GRAPH <{{named_graph}}> {
            {{{source_restriction}}}
            {{#property_paths}}
            OPTIONAL {
              ?{{source_restriction_variable}} {{property_path}} ?{{object_variable}} .
            }
            {{/property_paths}}
          }
        }",
        :named_graph => named_graph,
        :property_paths => property_paths,
        :source_restriction => source_restriction.text,
        :source_restriction_variable => source_restriction_variable
      )
     
      select_query = Mustache.render("
        {{{prefixes}}}

        {{{graph_pattern}}}",
        :graph_pattern => graph_pattern,
        :prefixes => prefixes
      )
     
      patterns = sparql_endpoint.query(select_query).map do |solution|
        object_values = solution.bindings

        property_paths.map do |property_path|
          object_value = object_values[property_path[:object_variable].to_sym]
          {
            :property_path => property_path[:property_path],
            :value => object_value ? object_value.to_ntriples : nil,
          }
        end
      end
    
      combinations = patterns.map do |pattern|
        if pattern.any? { |triple| triple[:value].nil? }
          nil_pattern = pattern
          non_nil_property_paths = nil_pattern.select do |triple|
            !triple[:value].nil?
          end.map do |triple|
            {:property_path => triple[:property_path],
             :value => triple[:value]}
          end
          
          matching_patterns = patterns.select do |pattern|
            pattern.all? do |triple|
              property_paths = non_nil_property_paths.map { |p| p[:property_path] }
              is_non_nil = property_paths.include? triple[:property_path]
              if is_non_nil
                required_value = non_nil_property_paths.detect do |p|
                  p[:property_path] == triple[:property_path]
                end[:value]
                triple[:value] == required_value
              else
                true
              end
            end
          end
          matching_patterns.map do |matching_pattern|
            {:source_pattern => nil_pattern,
             :target_pattern => matching_pattern}
          end
        else
          [{:source_pattern => pattern,
            :target_pattern => pattern}]
        end
      end.flatten(1)
   
      if combinations.count > max_rules
        raise Thor::Error, "The property paths #{property_paths.join(", ")} create more than "\
                           "#{max_rules} maximum number of rules (#{combinations.count}). "\
                           "Either increase the --max-rules option or provide property paths "\
                           "that yield less possible linkage rules."
      end

      # Render template restrictions for each combination 
      restrictions = combinations.map do |combination|
        source_restriction_pattern = get_restriction_pattern(
          source_restriction.text,
          source_restriction_variable,
          combination[:source_pattern]
        )
        target_restriction_pattern = get_restriction_pattern(
          target_restriction.text,
          target_restriction_variable,
          combination[:target_pattern]
        )
        [source_restriction_pattern, target_restriction_pattern]
      end

      output_path = @config[:output_path].content
      FileUtils.rm Dir.glob("#{output_path}/*") # Empty the output directory

      # Template each combination of restrictions into XML linkage rule and save it
      # to the output directory.
      restrictions.each do |restriction|
        source_restriction.content, target_restriction.content = restriction
        output_name = SecureRandom.uuid
        output_path_ext = File.extname output_path
        @config[:output_path].content = File.join(
          File.dirname(output_path),
          File.basename(output_path, output_path_ext) + "_" + output_name + output_path_ext
        )
        File.open(File.join(output_dir, output_name + ".xml"), "w") do |f|
          f.write(@rule.to_xml)
        end
      end
    end
    
    # Parses XML Silk linkage rule from file path `rule_path`.
    #
    # @param rule_path [String] Path to the parsed linkage rule
    # @return [Nokogiri::XML::Document]
    #
    def parse_rule(rule_path)
      raise "#{rule_path} doesn't exist." unless File.exists? rule_path
      Nokogiri::XML(File.open(rule_path))
    end
  end

  desc "link RULES_DIR SILK_PATH",
       "Execute linkage rules from RULES_DIR using Silk on SILK_PATH"
  option :log, :type => :boolean, :default => false,
         :desc => "Boolean flag for logging queries"
  option :threads, :type => :numeric, :default => 4,
         :desc => "Number of threads to use"
  def link(rules_dir, silk_path)
    raise "Directory #{rules_dir} doesn't exist." unless File.exists? rules_dir
    raise "Silk cannot be found at #{silk_path}." unless File.exists? silk_path

    linkage_rules = Dir["#{rules_dir.sub(/\/$/, "")}/*.xml"]
    linkage_rules.each do |linkage_rule|
      command = "java #{ENV["JAVA_OPTS"]} "\
                "-DconfigFile=#{linkage_rule} "\
                "-Dthreads=#{options[:threads]} "\
                "-DlogQueries=#{options[:log]} "\
                "-jar #{silk_path}"
      start_time = Time.now
      system command
      end_time = Time.now
      difference = (end_time - start_time) / 60
      puts "Finished executing linkage rule #{linkage_rule} in #{difference} minutes."
    end
  end

  desc "split RULE_PATH",
       "Splits linkage rule based on SPARQL 1.1 property path values"
  option :max_rules, :type => :numeric, :default => 500,
         :desc => "Limit to maximum number of generated rules"
  option :output, :type => :string, :required => true,
         :desc => "Path to output directory"
  option :property_paths, :type => :array,
         :default => ["pc:contractingAuthority/schema:address/schema:addressCountry", "pc:kind"],
         :desc => "List of property paths to use in splitting"
  def split(rule_path)
    @rule = parse_rule(rule_path)
    @config = extract_config()
    unless File.exists? options[:output]
      Dir.mkdir(options[:output])
    end

    get_restrictions(options[:property_paths], options[:output], options[:max_rules])
    puts "Generated linkage rules were put into #{options[:output]} directory."
  end
end

LinkageRuleSplitter.start(ARGV)
