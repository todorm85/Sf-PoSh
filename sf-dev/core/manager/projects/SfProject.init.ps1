$definition = @"
public class SfProject
{
    public string id { get; set; }
    public string displayName { get; set; }
    public string solutionPath { get; set; }
    public string webAppPath { get; set; }
    public string websiteName { get; set; }

    // needed for performance when selecting sitefinities
    public string branch { get; set; }
    public string description { get; set; }
    public string lastGetLatest { get; set; }
    public bool isInitialized { get; set; }
    public string tags { get; set; }
    public int daysSinceLastGet { get; set; }
}
"@

Add-Type -TypeDefinition $definition

function _newSfProjectObject ($id) {
    [SfProject]$newProject = [SfProject]::new()
    if (!$id) {        
        $newProject.id = _generateId    
    } else {
        $newProject.id = $id
    }

    return $newProject
}
