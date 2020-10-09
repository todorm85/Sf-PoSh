using System;
using System.Text;
using Microsoft.Http;
using SitefinityWebApp.SfDev;
using Telerik.Sitefinity.Authentication.Configuration;
using Telerik.Sitefinity.Configuration;
using Telerik.Sitefinity.Services;
using Telerik.Sitefinity.TestIntegration.Helpers;

namespace SitefinityWebApp.SfDev
{
    public static class UnrestrictedBackendServicesClient
    {
        private const string BasicAuthUserMail = "BackendServicesBasicAuthClient@test.test";
        private static CreateUserRegion basicAuhUser;
        private static HttpClient client;

        static UnrestrictedBackendServicesClient()
        {
            SetBasicAuth(true);
            client = new HttpClient();
            client.BaseAddress = new Uri(SystemManager.RootUrl);
        }

        // sends http request with current user credentials cookie
        public static HttpResponseMessage SendRequest(string method, string relativePath, string content = null)
        {
            var message = new HttpRequestMessage(method, relativePath);
            if (method != "GET")
                message.Headers.ContentLength = 0;

            if (content != null)
            {
                message.Content = HttpContent.Create(content);
                message.Headers.ContentLength = Encoding.ASCII.GetByteCount(content);
            }

            var bytes = Encoding.ASCII.GetBytes(BasicAuthUserMail + ":admin@2");
            message.Headers.Add("Authorization", "Basic " + Convert.ToBase64String(bytes));
            var result = client.Send(message);
            result.EnsureStatusIsSuccessful();
            return result;
        }

        public static void SetBasicAuth(bool enable)
        {
            using (new AdminUserRegion())
            {
                if (!Config.Get<AuthenticationConfig>().RelyingParty.EnableBasicAuthenticationForBackendServices)
                {
                    Config.UpdateSection<AuthenticationConfig>(x => x.RelyingParty.EnableBasicAuthenticationForBackendServices = enable);
                }

                basicAuhUser = new CreateUserRegion(BasicAuthUserMail, true);
            }
        }
    }
}