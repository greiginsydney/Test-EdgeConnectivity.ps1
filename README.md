# Test-EdgeConnectivity.ps1
This script performs a quick and easy test of the firewalling between your Front-end server and ALL Edge servers in the Topology. Add the "-site" switch to only retrieve those in a given topology site. It outputs the results to screen, to the pipeline and to a CSV file.

**7th August 2019 - v1.2**


The larger and more complex your on-prem SfB installation is, the greater the likelihood of encountering firewall problems.
If you run this script on your Front-End server(s) it will:
- query the topology to find all of the Edge servers. 
    - OR add the "-site" switch to only retrieve those in a given topology site  
    - OR add the "-TargetFqdn" followed by one or more servers in a comma- or space-separated list to skip the Topo test and test it/them only.
- initiate a TCP probe to all of them on all the ports that should be open: 443, 4443, 5061, 5062, 8057 + the CLS Logging ports 50001, 2 & 3 
- executes a TURN test to UDP 3478. (Thank you Frank Carius <a href="https://twitter.com/msxfaq">@msxfaq</a> for this code) 
- output the results to screen 
- output the results to the pipeline as an object 
- save the results in the log file in csv format 
 
<img id="218249" src="/site/view/file/218249/1/Test-EdgeConnectivity.jpg" alt="" width="843" height="245" />
<img id="220953" src="https://i1.gallery.technet.s-msft.com/test-edgeconnectivityps1-24bd669b/image/file/220953/1/test-edgeconnectivity-v1.1example.png" alt="" width="979" height="306" />
 
### Revision History
#### v1.2 7th August 2019.

- Added 'TCP' and 'UDP' headers to the output object 
- Added previously excluded CLS ports 50002 &amp; 50003 
- Added new '-ports' switch to let you specify one or more ports, overriding the defaults

> All port numbers except 3478 will be treated as TCP

- Moved "$udpClient.Send" line inside the Try so invalid FQDNs don't spray red on screen 

#### v1.1 7th April 2019.

- Added Frank Carius' UDP3478 test. Thank you Frank! 
- Added "-TargetFqdn" switch to force a test to a single machine - or a list. (Thanks Naimesh!) 
- Added write-progress to the port tests so you can see when it' stuck on a bad port 

#### 10th December 2018. This is the initial release.
 
If you encounter any problems with the script or can suggest improvements, please let me know in the comments, via Twitter (@greiginsydney) or in <a href="https://greiginsydney.com/test-edgeconnectivity-ps1" target="_blank">the accompanying post on my blog</a>.
 
Thanks,
 
- Greig.

<br>

This script was originally published at [https://greiginsydney.com/test-edgeconnectivity-ps1//](https://greiginsydney.com/test-edgeconnectivity-ps1//).
