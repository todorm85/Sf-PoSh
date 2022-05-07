public class SiteBinding
{
    public string protocol { get; set; }
    public string domain { get; set; }
    public string port { get; set; }

    public override bool Equals(object obj)
    {
        var other = (SiteBinding)obj;
        return this.protocol == other.protocol && this.domain == other.domain && this.port == other.port;
    }
    
    public override int GetHashCode()
    {
        return base.GetHashCode();
    }
}