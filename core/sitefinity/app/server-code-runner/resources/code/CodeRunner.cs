using System;
using System.Linq;
using System.Reflection;
using System.ServiceModel;
using System.ServiceModel.Web;

namespace SitefinityWebApp.SfDev
{
    [ServiceContract]
    public class CodeRunner
    {
        [OperationContract]
        [WebGet(UriTemplate = "/CallMethodWithAttribute/?attributeName={attributeTypeName}&typeName={instanceTypeName}", ResponseFormat = WebMessageFormat.Json)]
        public void CallMethodWithAttribute(string attributeTypeName, string instanceTypeName)
        {
            var attributeType = Type.GetType(attributeTypeName, true);
            var instanceType = Type.GetType(instanceTypeName, true);
            var setupMethod = instanceType.GetMethods().First(m => m.CustomAttributes.Any(a => a.AttributeType == attributeType));
            CallMethod(instanceType, setupMethod, new object[0]);
        }

        [OperationContract]
        [WebGet(UriTemplate = "/CallMethod/?methodName={methodName}&typeName={instanceTypeName}&params={parameters}", ResponseFormat = WebMessageFormat.Json)]
        public object CallMethod(string methodName, string instanceTypeName, string parameters)
        {
            var parsedParameters = parameters.Split(new char[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
            var instanceType = Type.GetType(instanceTypeName, true);
            var method = instanceType.GetMethods().First(m => m.Name == methodName && m.GetParameters().Count() == parsedParameters.Count());
            return CallMethod(instanceType, method, parsedParameters);
        }

        private object CallMethod(Type instanceType, MethodInfo method, object[] parameters)
        {
            using (new AdminUserRegion())
            {
                var instance = Activator.CreateInstance(instanceType);
                var result = method.Invoke(instance, parameters);
                return result;
            }
        }
    }
}