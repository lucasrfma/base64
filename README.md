### Base 64 encoder/decoder

Project done as a way of learning the zig language.

#### Done
 - Encode functionality
 - Decode functionality
 - Command line arguments:
   - encode sourcefile encodedfile
   - decode encodedfile decodedfile 

#### To do
 - Implement concurrency between reading and writing, and check performance results
 - Add command line options 
   - A help option (either '-h' or 'help' as single command line arguments)


#### Formatting

I usually like camelCase for variables and PascalCase for everything else...
But it seems zig's standard is snake_case for variables, and I wound up mixing it up.

Trying to make it more uniform now:

camelCase: functions (I'll probably use it for vars that are function ptrs as well)
snake_case: variables (and runtime consts, which are kinda like variables)
PascalCase: types (structs, enums) and (comptime) Consts (personal preference)