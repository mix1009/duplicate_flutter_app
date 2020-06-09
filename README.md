# duplicate_app

duplicate_app is a dart app for duplicating Flutter project folder. Tested on Mac and Windows.


## Getting Started

`
dart duplicate_app.dart --org com.company path_to_src_project new_project_name
`

This will copy entire src_project folder and create new_project_name in the same folder as src_project.
It will remove build, .git, .dart_tool folder from the new project folder.
It fixes all references to the old project org & name. and change it to new org & name.
Android src path is also taken care of.

## optional arguments:

--org : If omitted, it will use same org as the src_project.

-f : force overwrite. It will delete new_project folder if avaliable.

-t : test mode. It will output project parameters only and not do copy.

