## POWERSHELL COLLECTIONS ##

As usual, these scripts were solutions to particular issues I had, sometimes only once, which required a quick script. And because of interoperability with the NET environment, PowerShell is oftenmore useful than Python for these kinds of things....


### *.PS1 SCRIPTS ###

1. **combine_files** - meant to bypass LLM upload file count (but not size) - recursively search from script root down the directory tree, looking for file types of a given extension (*cs in the example), combining each file to the stack until a threshold size is reached (250 KB in the example.) Really meant for ASCII text... and really useful for uploading for example 250 CS files in a single LLM prompt, all combined into 5 or 6 files.
2. **dwm_hook_set_all_styles** - compiles a C# fragment then hooks/interops with DWM to set some style parameters on all appplicable windows. For example, make all borders red, remove rounded corners, and set immersive dark mode... if you want.
3. **rename_from_list.ps1** - Win11 introduces a right click, Copy as Path option, which combied with this makes it easy to rename all of those copied as path files with a specific prefix and suffix. Importantly, the script reads from a txt file (of file paths) in the root, although it could be modified to read from clipboard.