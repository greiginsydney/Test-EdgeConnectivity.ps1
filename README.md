# Test-EdgeConnectivity.ps1
This script performs a quick and easy test of the firewalling between your Front-end server and ALL Edge servers in the Topology. Add the "-site" switch to only retrieve those in a given topology site. It outputs the results to screen, to the pipeline and to a CSV file.

<p><span style="font-size: small;"><strong>7th August 2019 - v1.2</strong></span></p>
<p>------------------------</p>
<p>The larger and more complex your on-prem SfB installation is, the greater the likelihood of encountering firewall problems.</p>
<p>If you run this script on your Front-End server(s) it will:</p>
<ul>
<li>query the topology to find all of the Edge servers. 
<ul>
<li>OR add the &ldquo;-site&rdquo; switch to only retrieve those in a given topology site&nbsp; </li>
<li><span>OR add the "-TargetFqdn" followed by one or more servers in a comma- or space-separated list to skip the Topo test and test it/them only</span> </li>
</ul>
</li>
<li>initiate a TCP probe to all of them on all the ports that should be open: 443, 4443, 5061, 5062, 8057 + the CLS Logging ports 50001, 2 &amp; 3 </li>
<li>executes a TURN test to UDP 3478. (Thank you Frank Carius&nbsp;<a href="https://twitter.com/msxfaq">@msxfaq</a>&nbsp;for this code) </li>
<li>output the results to screen </li>
<li>output the results to the pipeline as an object </li>
<li>save the results in the log file in csv format </li>
</ul>
<p>&nbsp;</p>
<p><img id="218249" src="/site/view/file/218249/1/Test-EdgeConnectivity.jpg" alt="" width="843" height="245" /></p>
<p><img id="220953" src="https://i1.gallery.technet.s-msft.com/test-edgeconnectivityps1-24bd669b/image/file/220953/1/test-edgeconnectivity-v1.1example.png" alt="" width="979" height="306" /></p>
<p>&nbsp;</p>
<p>Revision History</p>
<p>v1.2 7th August 2019.</p>
<ul>
<li>Added 'TCP' and 'UDP' headers to the output object </li>
<li>Added previously excluded CLS ports 50002 &amp; 50003 </li>
<li>Added new '-ports' switch to let you specify one or more ports, overriding the defaults<br /> (All port numbers except 3478 will be treated as TCP) </li>
<li>Moved "$udpClient.Send" line inside the Try so invalid FQDNs don't spray red on screen </li>
</ul>
<p>v1.1 7th April 2019.</p>
<ul>
<li>Added Frank Carius&rsquo; UDP3478 test. Thank you Frank! </li>
<li>Added &lsquo;-TargetFqdn&rsquo; switch to force a test to a single machine &ndash; or a list. (Thanks Naimesh!) </li>
<li>Added write-progress to the port tests so you can see when it&rsquo;s stuck on a bad port </li>
</ul>
<p>10th December 2018. This is the initial release.</p>
<p>&nbsp;</p>
<p>If you encounter any problems with the script or can suggest improvements, please let me know in the comments, via Twitter (@greiginsydney) or in <a href="https://greiginsydney.com/test-edgeconnectivity-ps1" target="_blank">the accompanying post on my blog</a>.</p>
<p>&nbsp;</p>
<p>Thanks,</p>
<p>&nbsp;</p>
<p>- Greig.</p>
