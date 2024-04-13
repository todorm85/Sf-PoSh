using System;
using Telerik.Sitefinity.Multisite;
using Telerik.Sitefinity.Services;

namespace SitefinityWebApp.SfDev
{
    public class Utils
    {
        public static void RunForAllSites(Action callback)
        {
            foreach (var site in SystemManager.CurrentContext.GetSites())
            {
                using (new SiteRegion(site))
                {
                    callback();
                }
            }
        }
    }
}