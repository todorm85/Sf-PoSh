using System;

namespace SitefinityWebApp.SfDev
{
    public class Users
    {
        public void Seed(string email, string roles)
        {
            var rolesCol = roles.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
            new CreateUserRegion(email, rolesCol);
        }
    }
}