Vestnikverejnychzakazek.cz
==========================

It is "impossible" to run deduplicaton on whole dataset on one machine, but the dataset can be divided in several ways, two were leveraged for dividing the dataset into manageble chunks:

- By country: Czech republic (several forms), others and unkwown
- Those that have IČ (identification number) and those that do not

The group of business entities (BE) outside Czech republic is quite small and is run as one simple job against itself (non-cz--non-cz). The same goes for those with unknown country (unknown--unknown). The groups can be linked with one another (non-cz--unknown) and with Czech BEs (non-cz--cz and unknown--cz) as well. All these configurations compare by name only.

Czech BEs can by divided by presence of IČ. Those without can be linked in small chunks separated by the first letter of the name (cz-name--cz-name-...) (assumption is that first letter is correct, but in can omit some possible matches). They can also be linked in similar groups with those with IČ (cz-ico--cz-name...). Again only name comparison is used. These configurations were generated by a script (not listed) in a way that each group has similar number of entities.

Lastly BEs with IČ need to be linked with themselves. The rule is different and takes simmilarity of the IČ into account. The base rule is provided in cz-ico--cz-ico but specific configurations are generated by script ico_with_prefix.rb. Simmilar assupmtion is made and BEs are grouped by leading digits, in this case their equality. 

The script is in Ruby, but should be easy to understand. It just takes the template and replaces placeholders with generated snippets. Then it runs the configuration. Paths to Java and Silk mhave to be adjusted, as well as the Xmx parameter. Some groups of BEs are smaller and fast (leading digits 1, 3, 5, 8, 9), the others are more problematic. Not just by size, but because there are dense clusters (usually ministies or other public institutions) which occur very often. For reasonable time, the other groups (by leading digit) were separated even further by modification of the prefix variable. 