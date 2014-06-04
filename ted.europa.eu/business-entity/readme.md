# TED

## by_countries.rb

Takes base config.xml and generates rules for linking between instances with the same country up to 50.000.

## large_countries.rb

Uses config-part.xml to generate rules for countries with many instances, separates the rules by the first letter of the name.

## extra_large.rb

It is elaboration of the previous. In some cases separation by the first letter isn't that efficient and needs to go deeper. The need depends on similiarity of the names. In some cases this is sufficient, but in others there are common prefixes which don't add value and only complicate the comparison. Examples of this are Polish names for consorcia. These cases depend onthe current data and must be handled separately.

## cross.rb

Takes instances with no country and no address and matches them against the rest, separated by the first letter.

Addresses without country or address must be linked as well, the rule is simple to derive and can be supplied to the second script.