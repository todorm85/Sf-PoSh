using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Security;
using Telerik.Sitefinity.Configuration;
using Telerik.Sitefinity.Security;
using Telerik.Sitefinity.Security.Configuration;
using Telerik.Sitefinity.Security.Model;

namespace SitefinityWebApp.SfDev
{
    public class CreateUserRegion : IDisposable
    {
        #region Constructors

        public CreateUserRegion(string email, bool isAdmin, UserManager managerToUse = null)
        {
            var roles = new List<string>();
            if (isAdmin)
            {
                roles.Add(SecurityConstants.AppRoles.BackendUsers);
                roles.Add(SecurityConstants.AppRoles.Administrators);
            }

            this.Init(email, roles, managerToUse);
        }

        public CreateUserRegion(string email, IEnumerable<string> roles = null, UserManager managerToUse = null)
        {
            this.Init(email, roles, managerToUse);
        }

        public CreateUserRegion(string email, params string[] roles)
        {
            this.Init(email, roles, null);
        }

        public CreateUserRegion(string email, string firstName, string lastName, IEnumerable<string> roles, UserManager managerToUse = null)
        {
            this.Init(email, roles, managerToUse, firstName, lastName);
        }

        #endregion

        #region Properties

        public User User
        {
            get
            {
                return this.user;
            }
        }

        #endregion

        #region Public methods

        public void Dispose()
        {
            if (this.user != null)
            {
                var manager = UserManager.GetManager(null, transactionName);
                var userToDelete = manager.GetUser(this.user.Id);
                if (userToDelete != null)
                {
                    manager.Delete(userToDelete);
                    manager.Provider.CommitTransaction();
                }
            }
        }

        #endregion

        #region Private methods

        private void Init(string email, IEnumerable<string> roles = null, UserManager managerToUse = null, string firstName = null, string lastName = null)
        {
            var manager = managerToUse ?? UserManager.GetManager(null, transactionName);

            SecurityManager securityManager = SecurityManager.GetManager(AppPermission.Root.DataProviderName);

            var validateUserInRole = true;
            this.user = manager.GetUser(email);
            if (this.user == null)
            {
                MembershipCreateStatus stat;
                this.user = manager.CreateUser(email, Password, "", "", true, Guid.NewGuid(), out stat);
                user.FirstName = firstName;
                user.LastName = lastName;

                if (stat != MembershipCreateStatus.Success)
                    throw new InvalidOperationException(stat.ToString());

                validateUserInRole = false;
            }

            manager.Provider.CommitTransaction();

            if (roles != null && roles.Any())
            {
                var roleManager = RoleManager.GetManager();

                foreach (var role in roles)
                {
                    if (validateUserInRole && roleManager.IsUserInRole(this.user.Id, role))
                        continue;

                    Role roleObj = null;
                    if (Config.Get<SecurityConfig>().ApplicationRoles.ContainsKey(role))
                    {
                        roleObj = roleManager.GetRole(Config.Get<SecurityConfig>().ApplicationRoles[role].Id);
                    }
                    else
                    {
                        roleObj = roleManager.GetRoles().FirstOrDefault(x => x.Name == role);
                    }

                    roleManager.AddUserToRole(this.user, roleObj);
                }

                roleManager.SaveChanges();
            }
        }

        #endregion

        #region Fields and constants

        public const string Password = "admin@2";

        private User user;
        private string transactionName = Guid.NewGuid().ToString();

        #endregion
    }
}
