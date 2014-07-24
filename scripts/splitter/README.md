# Linkage rule splitter

Splits Silk linkage rule into multiple rules based on SPARQL 1.1 property paths and their values.

## Dependencies

* Ruby version >= 1.9.3
* [Bundler](http://bundler.io/)

## Use

```bash
# Install dependencies from Gemfile
bundle install
# Get instructions how to run the splitter
ruby ./linkage_rule_splitter.rb help split
# Get instructions how to execute the generate linkage rules
ruby ./linkage_rule_splitter.rb help link
```

## Known caveats

* Only supports a single data source at the moment.
* Only rules for existing combinations of property paths' objects are counted. Combinations of missing objects with the available objects are not included. Possible solution: avoid `COUNT` query and count the rules using the `SELECT` query results and their additional combinations. 

