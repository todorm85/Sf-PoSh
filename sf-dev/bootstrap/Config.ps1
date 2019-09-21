$definition = @"
public class Config
{
    public string dataPath { get; set; }
    public string idPrefix { get; set; }
    public string projectsDirectory { get; set; }
    public string browserPath { get; set; }
    public string vsPath { get; set; }
    public string msBuildPath { get; set; }
    public string tfsServerName { get; set; }
    public string defaultUser { get; set; }
    public string defaultPassword { get; set; }
    public string sqlServerInstance { get; set; }
    public string sqlUser { get; set; }
    public string sqlPass { get; set; }
    public string[] predefinedBranches { get; set; }
    public string[] predefinedBuildPaths { get; set; }
}
"@

Add-Type -TypeDefinition $definition