public class SfProject
{
    public string id { get; set; }
    public string displayName { get; set; }
    public string solutionPath { get; set; }
    public string webAppPath { get; set; }
    public string websiteName { get; set; }

    public string branch { get; set; }
    public string description { get; set; }
    public System.Nullable<System.DateTime> lastGetLatest { get; set; }
    public bool isInitialized { get; set; }
    public string[] tags { get; set; }
    public SiteBinding defaultBinding { get; set; }

    public System.Nullable<int> GetDaysSinceLastGet()
    {
        if (!this.lastGetLatest.HasValue)
        {
            return null;
        }

        var days = System.DateTime.Today - this.lastGetLatest.Value.Date;
        return (int)System.Math.Round(days.TotalDays, 0);
    }
}