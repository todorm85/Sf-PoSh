using System;
using System.Linq;
using System.Web;
using Telerik.Sitefinity.Security;

namespace SitefinityWebApp.SfDev
{
    public class AdminUserRegion : IDisposable
    {
        private readonly AuthenticateUserRegion authenticatedRegion;
        private int oldTimeout;

        public AdminUserRegion()
        {
            this.oldTimeout = HttpContext.Current.Server.ScriptTimeout;
            HttpContext.Current.Server.ScriptTimeout = 3600;
            var um = UserManager.GetManager();
            foreach (var u in um.GetUsers().Take(50))
            {
                if (RoleManager.GetAllRolesOfUser(u.Id).Any(x => x.Name == SecurityConstants.AppRoles.Administrators))
                {
                    this.authenticatedRegion = new AuthenticateUserRegion(u);
                    break;
                }
            }

            if (this.authenticatedRegion == null)
            {
                throw new InvalidProgramException("No admin user found.");
            }
        }

        public void Dispose()
        {
            HttpContext.Current.Server.ScriptTimeout = this.oldTimeout;
            this.authenticatedRegion.Dispose();
        }
    }
}