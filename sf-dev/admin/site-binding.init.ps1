$definition = @"
public class SiteBinding
{
    public string domain { get; set; }
    public string port { get; set; }
}
"@

Add-Type -TypeDefinition $definition
