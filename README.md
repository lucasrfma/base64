### Base 64 encoder/decoder

Project done as a way of learning the zig language.

#### Done
 - Encode functionality
 - Decode functionality
 - Command line arguments:
   - encode sourcefile encodedfile
   - decode encodedfile decodedfile 
   - help

Help message is printed if 'help' or '-h' argument is used. If a wrong argument is used, a message telling the user it was an incorrect input is printed, along with the help message.

#### In progress
 - Implement concurrency between reading and writing, and check performance results

Implemented basic concurrency:
 - Worker: 
   - reads the original file
   - applies the desired function (encode or decode)
   - enqueues result
 - Saver: 
   - writes the result to file.

Did a simple manual testing comparing this version to single threaded (ST) version:
 - compiling  with --release=fast and -Dlog-level=warn
 - Tested decoding a encoded pptx file (og file is 10616KB, encoded one is 14155KB)
 - ran this 5x for each version:
   - ST version:
     - 4 runs with very similar time of around 76ms
     - 1 outlier with a runtime of 195 ms. Avg including outlier 99.74ms
   - Concurrent version:
     - 4 runs with very similar time of around 69ms
       - A decrease of 8.94% in time, so around 10% increased speed
     - 1 outlier with a runtime of 367ms, so a much bigger spike. Avg including outlier: 128.64ms.

Conclusion: seems faster, but the bigger spike is a bummer. 
Better testing required.
Also, maybe trying to increase the number of workers.

#### Formatting

I usually like camelCase for variables and PascalCase for everything else...
But it seems zig's standard is snake_case for variables, and I wound up mixing it up.

Trying to make it more uniform now:

camelCase: functions (I'll probably use it for vars that are function ptrs as well)
snake_case: variables (and runtime consts, which are kinda like variables)
PascalCase: types (structs, enums) and (comptime) Consts (personal preference)
