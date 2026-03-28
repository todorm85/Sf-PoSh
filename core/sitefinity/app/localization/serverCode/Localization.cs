using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Telerik.Sitefinity.Localization.Configuration;
using Telerik.Sitefinity.Multisite;
using Telerik.Sitefinity.Services;

namespace SitefinityWebApp.SfDev
{
    public class Localization
    {
        public void AddCulturesToSite(string siteIndex, string cultures)
        {
            DoWithCulturesForSite(siteIndex, cultures,
                (keys, currentSite) =>
                {
                    foreach (var key in keys)
                    {
                        if (!currentSite.CultureKeys.Contains(key))
                        {
                            currentSite.CultureKeys.Add(key);
                        }
                    }
                });
        }

        public void RemoveCulturesFromSite(string siteIndex, string cultures)
        {
            DoWithCulturesForSite(siteIndex, cultures,
                (keys, currentSite) =>
                {
                    foreach (var key in keys)
                    {
                        if (currentSite.CultureKeys.Contains(key))
                        {
                            currentSite.CultureKeys.Remove(key);
                        }
                    }
                });
        }


        public void SetSiteDefualtCulture(string siteIndexInput, string culture)
        {
            var siteIndex = int.Parse(siteIndexInput);
            var multisiteManager = MultisiteManager.GetManager();
            var currentSite = multisiteManager.GetSite(SystemManager.CurrentContext.GetSites().ToList()[siteIndex].Id);
            currentSite.DefaultCultureKey = CulturesConfig.GenerateCultureKey(CultureInfo.GetCultureInfo(culture), CultureInfo.GetCultureInfo(culture));
            multisiteManager.Provider.SuppressSecurityChecks = true;
            multisiteManager.SaveChanges();
        }

        private void DoWithCulturesForSite(string siteIndexInput, string culturesInput, Action<IEnumerable<string>, Telerik.Sitefinity.Multisite.Model.Site> callback)
        {
            var siteIndex = int.Parse(siteIndexInput);
            var cultures = culturesInput.Split(',');
            var multisiteManager = MultisiteManager.GetManager();
            var currentSite = multisiteManager.GetSite(SystemManager.CurrentContext.GetSites().ToList()[siteIndex].Id);
            var keys = cultures.Select(c => CulturesConfig.GenerateCultureKey(CultureInfo.GetCultureInfo(c), CultureInfo.GetCultureInfo(c))).ToList();
            callback(keys, currentSite);
            multisiteManager.Provider.SuppressSecurityChecks = true;
            multisiteManager.SaveChanges();
        }
    }
}