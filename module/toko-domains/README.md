# Dev Domains

## Description

Allows easy rerouting of domains to any localhost port. Ex. todor.com will be redirected to localhost:1111, gosho.com will be redirected to localhost:5511.

The module is basically a wrapper around the hosts file and the port proxy tool available in Windows. It creates an entry in the hosts file using one of the loopback address space 127.5.5.0/24 and then addds a port proxy redirect for that address to 127.0.0.1 using the supplied port.

__Module must be run in elevated Powershell session.__

- See [module definition](https://github.com/todorm85/dev-domains/blob/master/dev-domains.psd1) for requirements.

- [Official Installation Instructons for Powershell Modules](https://msdn.microsoft.com/en-us/library/dd878350(v=vs.85).aspx#Anchor_1)

- Allowing the module to run ([description](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-6#required-parameters)):
``` PS
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted
```
## How to use
``` PS
Show-Domains
```
- lists all registered domains and the local ports to which they are mapped

``` PS
Add-Domain -hostname {name} -mappedLocalPort {port number}
```
- Adds a reroute for the given hostname to the given localhost port

``` PS
Remove-Domain -domain
```
- Removes the specified domain from rerouting