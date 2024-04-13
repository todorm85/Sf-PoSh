using Telerik.Sitefinity.Configuration;
using Telerik.Sitefinity.Localization.Configuration;
using Telerik.Sitefinity.Multisite;
using Telerik.Sitefinity.Multisite.Web.Services;
using Telerik.Sitefinity.Multisite.Web.Services.ViewModel;
using Telerik.Sitefinity.Services;
using System.Linq;
using Telerik.Sitefinity.Configuration.Web;

namespace SitefinityWebApp.SfDev
{
    public class Sites
    {
        public void Seed(string countRaw, string duplicateFromDefaultSite)
        {
            var numberOfSitesToCreate = int.Parse(countRaw);
            var currentSitesCount = MultisiteManager.GetManager().GetSites().Count();
            var service = new MultisiteService();
            var numberOfSitesBeforeRestart = 200;

            var defaultSite = SystemManager.CurrentContext.MultisiteContext.GetSites().Single(s => s.IsDefault);
            var cultures = Config.Get<ResourcesConfig>().Cultures.Values.Select(c => new CultureViewModel(c)).ToList();
            var defaultCulture = cultures.FirstOrDefault(x => x.IsDefault);
            if (defaultCulture == null)
            {
                cultures.First().IsDefault = true;
            }

            var url = defaultSite.LiveUrl;
            var name = defaultSite.Name;

            for (int i = 0; i < numberOfSitesToCreate; i++)
            {
                var siteName = string.Concat(name, " ", (currentSitesCount + i));
                var site = new SiteConfigurationViewModel
                {
                    Name = siteName,
                    LiveUrl = string.Concat(url, "/", (currentSitesCount + i)),
                    DataSources = service.GetNewSiteSourcesConfiguration(siteName).ToList()
                };
                foreach (var ds in site.DataSources)
                {
                    ds.AllowMultipleProviders = true;
                    ds.IsChecked = true;
                    if (ds.Links.Count == 0)
                    {
                        ds.Links.Add(ds.SampleLink);
                    }
                }

                site.PublicContentCultures = cultures;

                if (duplicateFromDefaultSite.ToLower() == "true")
                {
                    site.SourcePagesSiteId = defaultSite.Id;
                }

                service.CreateSite(site);
                SystemManager.ClearCurrentTransactions();

                if ((i % numberOfSitesBeforeRestart) == 0)
                {
                    SystemManager.RestartApplication(string.Format("{0} sites has been created", numberOfSitesBeforeRestart));
                }
            }
        }

    }
}
