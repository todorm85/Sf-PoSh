# the path where provisioned sitefinity projects by the script will be created in. The directory must exist.
$script:projectsDirectory = "E:\dev-sitefinities"

# where info about created and imported sitefinities will be stored
$script:dataPath = "${projectsDirectory}\db.xml"

# Global settings
$script:defaultUser = 'admin'
$script:defaultPassword = 'admin@2'

$script:idPrefix = "sf_dev_"