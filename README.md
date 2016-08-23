# Tool for local sitefinity instance management

## Description
This tool allows easy sitefinity web apps setup and teardown on a local machine. It automates the process of creating a workspace in tfs, getting the latest changes, creating a website and hosting the app there as well as complete rollback. It also provides automation of resetting, rebuilding, cleaning of the web app and more.

## Prerequisites
- Powershell 4.0 or later
- Open for edit sitefinity.ps1 and in the beginning of the file there is a section 'Environment Constants'. Please, enter your environment specific paths there in order for all functionality to work correctly.

## Usage
Navigate to the directory where sitefinity.ps1 is located. Open a powershell instance with admin rights there. 'Dot source' the script by entering: `. ./sitefinity.ps1` (Note there are two dots, delimted by spacial character).

## Functions
Optional params given in []

### Sitefinity instances management

`sf-create-sitefinity -name "{theName}" [-branch "{theBranch}"]`
- if branch not specified the hardcoded in sitefinity.ps1 script will be used
- if name is not specified user will be prompted
- the script uses sf-data.xml file to persist sitefinity instances that are managed by it. You can also add entries there for manually created ones:
`<sitefinity name="" solutionPath="" workspaceName="" dbName="" websiteName="" port="" appPool="" />`
When doing so don't add workspace name if you don't use it exclusively for that sitefinity instance. It will be deleted if you use `sf-delte-sitefinity`
- the conventions used can be changed in the script in function `_sfData-apply-contextConventions`

Example: `sf-create-sitefinity "TestSitefinity" "$/CMS/Sitefinity 4.0/OfficialReleases/DBP"`
Will create the following:
- new workspace named TestSitefinity with local mapping of the DBP branch to d:\TestSitefinity
- new website called TestSitefinity with app path to d:\TestSitefinity\SitefinityWebApp and the first avbailable port starting from 1111. Default app pool is used by default.
- the web app will be initiated with startupConfig and a database named TestSitefinity will be created. The app will be added default admin user called

`sf-show-sitefinities`
- lists all sitefinities managed by the script (located in sf-data.xml)

`sf-delete-sitefinity`
- Deletes the currently selected sitefinity instance. Removes all including the workspace, website, database, local directories.

`sf-`