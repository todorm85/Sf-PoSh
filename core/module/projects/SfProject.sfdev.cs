public class SfProject
{
    public SfProject()
    {
        this.tags = new System.Collections.Generic.List<string>();
    }

    public string id { get; set; }
    public string displayName { get; set; }
    public string solutionPath { get; set; }
    public string webAppPath { get; set; }
    public string websiteName { get; set; }

    // public string branch { get; set; }
    // public string branchDisplayName
    // {
    //     get
    //     {
    //         if (string.IsNullOrEmpty(this.branch))
    //         {
    //             return "";
    //         }
    //         else
    //         {
    //             return this.branch.Replace("$/CMS/Sitefinity 4.0/", "").Replace("OfficialReleases/", "");
    //         }
    //     }
    // }
    public string description { get; set; }
    public System.Nullable<System.DateTime> lastGetLatest { get; set; }
    public bool isInitialized { get; set; }
    public System.Collections.Generic.List<string> tags { get; set; }
    public SiteBinding defaultBinding { get; set; }
    public System.Nullable<int> daysOld
    {
        get
        {
            if (!this.lastGetLatest.HasValue)
            {
                return null;
            }

            var days = System.DateTime.Today - this.lastGetLatest.Value.Date;
            return (int)System.Math.Round(days.TotalDays, 0);
        }
    }

    // Intellisense properties that will be overriden in powershell with script logic
    public string nlbId { get; set; }
    public string dbName { get; set; }
    public string version { get; set; }
    public string branch { get; set; }
    public string behind { get; set; }

    public override bool Equals(object obj)
    {
        var other = (SfProject)obj;
        return this.id == other.id;
    }

    public override int GetHashCode()
    {
        return base.GetHashCode();
    }
}