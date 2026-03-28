using System;
using Telerik.Sitefinity.Security;
using Telerik.Sitefinity.Security.Claims;
using Telerik.Sitefinity.Security.Model;

namespace SitefinityWebApp.SfDev
{
    public class AuthenticateUserRegion : IDisposable
    {
        public AuthenticateUserRegion(User user, UserManager manager = null)
        {
            this.user = user;
            this.manager = manager ?? UserManager.GetManager();

            var currentUserId = ClaimsManager.GetCurrentUserId();
            if (currentUserId != Guid.Empty)
            {
                this.previousUserId = currentUserId;
                SecurityManager.Logout();
            }

            if (user != null)
            {
                User dummy = null;
                SecurityManager.AuthenticateUser(null, user.Email, false, out dummy);
            }
        }

        public void Dispose()
        {
            var currentUserId = ClaimsManager.GetCurrentUserId();
            if (currentUserId != Guid.Empty)
            {
                SecurityManager.Logout();
            }

            if (this.previousUserId != Guid.Empty)
            {
                var previousUser = this.manager.GetUser(this.previousUserId);
                User dummy = null;
                SecurityManager.AuthenticateUser(null, previousUser.Email, false, out dummy);
            }
        }

        private User user;
        private User otherUser;
        private Guid previousUserId;
        private UserManager manager;
    }
}
