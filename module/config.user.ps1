# the path where provisioned sitefinity projects by the script will be created in. The directory must exist.
$global:projectsDirectory = "E:\dev-sitefinities"

# where info about created and imported sitefinities will be stored
$global:dataPath = "${projectsDirectory}\db.xml"

# Global settings
$global:defaultUser = 'admin@test.test'
$global:defaultPassword = 'admin@2'

$global:idPrefix = "sf_dev_"