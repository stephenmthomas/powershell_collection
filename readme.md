## POWERSHELL COLLECTIONS ##

As usual, these scripts were solutions to particular issues I had, sometimes only once, which required a quick script. And because of interoperability with the NET environment, PowerShell is oftenmore useful than Python for these kinds of things for Windows machines.


### *.PS1 SCRIPTS ###

1. **combine_files** - meant to bypass LLM upload file count (but not size) - recursively search from script root down the directory tree, looking for file types of a given extension (*cs in the example), combining each file to the stack until a threshold size is reached (250 KB in the example.) Really meant for ASCII text... and really useful for uploading for example 250 CS files in a single LLM prompt, all combined into 5 or 6 files.
2. **dwm_hook_set_all_styles** - compiles a C# fragment then hooks/interops with DWM to set some style parameters on all appplicable windows. For example, make all borders red, remove rounded corners, and set immersive dark mode... if you want.
3. **rename_from_list.ps1** - Win11 introduces a right click, Copy as Path option, which combied with this makes it easy to rename all of those copied as path files with a specific prefix and suffix. Importantly, the script reads from a txt file (of file paths) in the root, although it could be modified to read from clipboard.
4. **scan_dir.ps1** - script that searches down into the directory tree and reports back all the files, logs the output to a text file. Accepts two lists to ignore directories, and capacity to ignore or accept only certain kinds of file extension, and options for recursive depth and output path trimming. Very useful for communicating project architecture exactly under otherwise crowded or non-specific/cluttered project environments.
5. **serve.ps1** - creates an npx server rooted in the directory of the ps1 file, at https://localhost:$port (default 8080) and launches a new Chrome window, loading index.html (et al) - designed when  I was having CORS issues when an inert and non-risky project.
6. **svg_recolor.ps1** - recolors all SVGs in a directory branch - ALL color attribute/properties are set to the specified color. Backup before using. Nominally meant to be used to recolor large UI icon collections.
