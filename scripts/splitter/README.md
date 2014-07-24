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
