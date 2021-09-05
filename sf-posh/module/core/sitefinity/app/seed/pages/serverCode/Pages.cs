using System;
using System.Collections.Generic;
using System.Linq;
using Telerik.Sitefinity;
using Telerik.Sitefinity.Abstractions;
using Telerik.Sitefinity.Modules.Pages;
using Telerik.Sitefinity.Pages.Model;
using Telerik.Sitefinity.TestUtilities.CommonOperations;
using Telerik.Sitefinity.TestUtilities.Modules.Pages;

namespace SitefinityWebApp.SfDev
{
    public class Pages
    {
        public void Seed(string countRaw, string levelsRaw, string allSites)
        {
            var count = int.Parse(countRaw);
            var levels = int.Parse(levelsRaw);
            if (allSites.ToLower() == "true")
            {
                Utils.RunForAllSites(() =>
                {
                    this.CreateHierarchy(count, levels);
                });
            }
            else
            {
                this.CreateHierarchy(count, levels);
            }
        }

        public void DeleteAll(string allSites)
        {
            if (allSites.ToLower() == "true")
            {
                Utils.RunForAllSites(() =>
                {
                    ServerOperations.Pages().DeleteAllPages();
                });
            }
            else
            {
                ServerOperations.Pages().DeleteAllPages();
            }
        }

        public void AddContentWidgetToAllPages()
        {
            var rootPage = PageManager.GetManager().GetPageNode(SiteInitializer.CurrentFrontendRootNodeId);
            foreach (var p in rootPage.Nodes)
            {
                var pData = p.GetPageData();
                ServerOperations.Widgets().AddContentBlockToPage(p.Id, Guid.NewGuid().ToString(), "Body", "Content block");
            }
        }

        public void CreateChildPages(string urlName, string countRaw, string baseTitle)
        {
            var count = int.Parse(countRaw);
            var pageFacade = App.WorkWith().Page();
            var man = pageFacade.GetManager() as PageManager;
            PageNode parent = null;
            if (string.IsNullOrEmpty(urlName))
            {
                parent = man.GetLocationRoot(Telerik.Sitefinity.Fluent.Pages.PageLocation.Frontend);
            }
            else
            {
                parent = man.GetPageNodes().First(p => p.UrlName == urlName);
            }

            var createdPages = new List<PageNode>();
            for (int i = 0; i < count; i++)
            {
                pageFacade.CreateNewStandardPage(parent)
                    .Do(p =>
                    {
                        p.Title = baseTitle + "_" + i;
                        p.UrlName = p.Title;
                    })
                    .CheckOut()
                    .Publish();
            }

            pageFacade.SaveChanges();
        }

        private void CreateHierarchy(int count, int levelsCount)
        {
            new PageCreator().
                CreatePageHierarchy(new PageCreator.HierarchicalPage(SiteInitializer.CurrentFrontendRootNodeId),
                count, levelsCount);
        }
    }
}
