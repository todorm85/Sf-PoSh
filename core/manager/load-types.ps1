try {
    # Wrap in a try-catch in case we try to add this type twice.
    # Create a class to hold an IIS Application Service's Information.
    Add-Type -TypeDefinition @"
        using System;
         
        public class SfProject
        {
            public string id { get; set;}
            public string displayName { get; set;}
            public string solutionPath { get; set;}
            public string webAppPath { get; set;}
            public string websiteName { get; set;}
            public string branch { get; set;}
            public string description { get; set;}
            public string containerName { get; set;}

            public SfProject() { }
            public SfProject(string id, string displayName) 
            {
                this.id = id;
                this.displayName = displayName;
            }
        }
"@
}
catch {}