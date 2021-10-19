#
:global brName  "bridgeLocal";
:global logPref "defconf:";
:global mgmtListName "MGMT_List"
:global structVLAN {
  "MGMT"={name="MGMT";vid=99;comment="MGMT VLAN 99"};
  "CAPs"={name="CAPs";vid=200;comment="CAPs discovery VLAN 200"};
  "WiFi"={name="WiFi";vid=100;comment="WiFi VLAN 100"}
};
:global mgmtIntrface "";
:global capsInterface "";
:global bridgeInterface "";
:global arrayWiFiInterface "";
:global mgmtList "";

# wait for ethernet interfaces
:global count 0;
:while ([/interface ethernet find] = "") do={
  :if ($count = 30) do={
    :log warning "DefConf: Unable to find ethernet interfaces";
    /quit;
  }
  :delay 1s; 
  :set count ($count + 1);
}

:global macSet 0;
:global tmpMac "";
:foreach k in=[/interface ethernet find] do={
  # first ethernet is found; add bridge and set mac address of the ethernet port
  :if ($macSet = 0) do={
    :set tmpMac [/interface ethernet get $k mac-address];
    :set bridgeInterface [/interface bridge add name=$brName auto-mac=no admin-mac=$tmpMac vlan-filtering=yes frame-types=admit-only-vlan-tagged ingress-filtering=yes comment="defconf"]; # get reference to bridge interface
    #:set bridgeInterface [/interface bridge add name=$brName auto-mac=no admin-mac=$tmpMac vlan-filtering=yes comment="defconf"]; # get reference to bridge interface
    :set macSet 1;
  }
  # add bridge ports
  /interface bridge port add bridge=$bridgeInterface interface=$k comment="defconf" 
}
  
:global firstEthInterface [/interface ethernet find default-name="ether1"]; # get reference first ethernet interface 
:global lastEthInterface ([interface ethernet find]->([:len [/interface ethernet find]]-1)); # get reference last ethernet interface
:global arrayTagInterface {$bridgeInterface;$firstEthInterface}; # make array tagget VLAN interface
:global arrayUnTagInterface [/interface ethernet find default-name~"ether" and .id!=$firstEthInterface and .id!=$lastEthInterface]; # get array ethernet interface exclude fist & last ethernet interface 

:foreach iname,data in=$structVLAN do={
  if ($iname="WiFi") do={
    /interface bridge vlan add bridge=$bridgeInterface vlan-ids=($data->"vid") tagged=$firstEthInterface untagged=$arrayUnTagInterface comment=($data->"comment");
    :foreach i in=$arrayUnTagInterface do={
      /interface bridge port set [find interface=[/interface ethernet get $i name]] ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged pvid=($data->"vid");
    } 
  } 
  if ($iname="MGMT") do={
    /interface bridge vlan add bridge=$bridgeInterface vlan-ids=($data->"vid") tagged=$arrayTagInterface untagged=$lastEthInterface comment=($data->"comment");
    :set mgmtIntrface [/interface vlan add interface=$bridgeInterface vlan-id=($data->"vid") name=$iname comment=($data->"comment")]; # get reference management interface
    #/ip address add interface=$mgmtIntrface address=[:toip ($data->"ipAddr")] netmask=[:toip ($data->"netMask")] comment=($data->"comment"); # set ip addresses to management interface
    /interface bridge port set [find interface=[/interface ethernet get $lastEthInterface name]] ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged pvid=($data->"vid");
  }
  if ($iname="CAPs") do={
    /interface bridge vlan add bridge=$bridgeInterface vlan-ids=($data->"vid") tagged=$arrayTagInterface comment=($data->"comment");
    :set capsInterface [/interface vlan add interface=$bridgeInterface vlan-id=($data->"vid") name=$iname comment=($data->"comment")]; # get reference CAPsMAN discovery interface
    /interface bridge port set [find interface=[/interface ethernet get $firstEthInterface name]] ingress-filtering=yes frame-types=admit-only-vlan-tagged;
  }
}


do {
  :set mgmtList [/interface list add name=$mgmtListName];
  /interface list member add list=$mgmtList interface=$mgmtIntrface;
  /interface list member add list=$mgmtList interface=$lastEthInterface;
  /ip neighbor discovery-settings set discover-interface-list=$mgmtList;
  /tool mac-server set allowed-interface-list=$mgmtList;
  /tool mac-server mac-winbox set allowed-interface-list=$mgmtList;
}

do {
  /tool romon set enabled=yes
} on-error={ :log warning "$logPref unable to configure romon";}

# wait for wireless interfaces
:while ([/interface wireless find] = "") do={
  :if ($count = 30) do={
    :log warning "DefConf: Unable to find wireless interfaces";
    /quit;
  }
  :delay 1s; 
  :set count ($count + 1);
}

# delay just to make sure that all wireless interfaces are loaded
#:delay 5s;
:set arrayWiFiInterface [/interface wireless find];

:do {
  /interface wireless cap set enabled=yes interfaces=$arrayWiFiInterface discovery-interfaces=$capsInterface bridge=$bridgeInterface
} on-error={ :log warning "$logPref unable to configure caps";}
