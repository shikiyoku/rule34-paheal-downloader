ABANDONED

Just use [Grabber](https://github.com/Bionus/imgbrd-grabber)

# rule34-paheal Downloader
Set of powershell scripts for downloading and categorizing images from http://rule34.paheal.net

# Tags file format
A tags file contains list of tags (one per line). Tag becomes a folder name.
```
Frozen
The_Little_Mermaid
```
You can also group tags by putting `:` after the tag. Only tags specified after `:` will be matched to file name.

```
Frozen : Frozen Elsa Anna
```

# Download.ps1
Downloads site feed images.
You need to set up `Download.config` (use `Download.config.example` as an example):
```ini
; Start page to download
StartPage=1
; Download folder
DestinationRoot=C:\Download\rule34
; Post id to stop downloading at
StopId=2267636
; File containing tags indicating images that must be put in separate folder
TrashTagsFile=.\tags_trash.txt
; Whether to shutdown PC after download is completed
ShutdownPC=false
```

There are two steps:
- Collecting image URLs: Script downloads list pages starting from `StartPage` and collects images URLs. Once image with `StopId` is reached script saves images data into `media.csv`
- Downloading images: Looping through image URLs received on the previous step script downloads images. Any error logged into `errors.csv`. When all images processed script calls `Categorize` using tags from `TrashTagsFile`

# Categorize-and-Move.ps
Categorizes images by file type and tags.
You need to set up `Categorize-and-Move.config` (use `Categorize-and-Move.config.example` as an example):
```ini
; Source folder
SrcPath=C:\Download\rule34\ready
; Destination folder. Set the same as SrcPath to categorize w/o moving
DestPath=X:\pictures\rule34
; Tags file path
TagsFilePath=.\tags_series.txt
```

# Get-TagsFrequency.ps1
Builds tags frequency list for specified folder.
You need to set up `Get-TagsFrequency.config` (use `Get-TagsFrequency.config.example` as an example):

```ini
; Folder containing images
Path=X:\pictures\rule34\
; Tag files' paths separated by "|"
TagFilePaths=.\tags_artist.txt | .\tags_character.txt | .\tags_exclude.txt
```
