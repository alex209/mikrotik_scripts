:global brName  "bridgeLocal";
:global logPref "defconf:";
:global mgmtListName "MGMT_List"
:global structVLAN {
  "MGMT"={name="MGMT";vid=99;comment="MGMT"};
  "CAPs"={name="CAPs";vid=200;comment="CAPs discovery"};
  "KPG5_consulate"={name="vlan.50";vid=50;comment="KPG5 Consulate"};
  "KPG5_VoIP"={name="vlan.51";vid=51;comment="KPG5 VoIP"};
  "Kvartiry"={name="vlan.52";vid=52;comment="Kvartiry"};
  "CONS_Inet"={name="vlan.53";vid=53;comment="Consulate Intenet"};
  "Clean_Inet"={name="vlan.55";vid=55;comment="Clean Internet"};
  "KPG6_Internet"={name="vlan.60";vid=60;comment="KPG6 Internet"};
  "KPG6_BUH"={name="vlan.61";vid=61;comment="KPG6 BUH VLAN"};
  "BT_Internet"={name="vlan.62";vid=62;comment="BT Internet"}
};
:global mgmtIntrface "";
:global capsInterface "";
:global bridgeInterface "";
:global mgmtList "";
:global strTagInterface "";

# wait for ethernet interfaces
:local count 0;
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
    :set bridgeInterface [/interface bridge add name=$brName auto-mac=no admin-mac=$tmpMac vlan-filtering=yes frame-types=admit-only-vlan-tagged ingress-filtering=yes comment="defconf"];
    :set macSet 1;
  }
  # add bridge ports
  /interface bridge port add bridge=$bridgeInterface interface=$k comment="defconf"
}

:global firstEthInterface [/interface ethernet find default-name="ether1"]; # get first ethernet interface 
:global lastEthInterface ([interface ethernet find default-name~"ether"]->([:len [/interface ethernet find default-name~"ether"]]-1)); # get last ethernet interface
:global tagInterface [/interface ethernet find default-name~"sfp"]; # get array sfp interface
:global arrayTagInterface {$tagInterface;$bridgeInterface}; # make array tagget VLAN interface
:global arrayUnTagInterface [/interface ethernet find default-name~"ether" and .id!=$lastEthInterface]; # get array ethernet interface exclude last ethernet interface 

:set strTagInterface $brName;
:foreach istr in=$tagInterface do={
   :set strTagInterface "$strTagInterface,$[/interface get $istr name]";
}
:put $strTagInterface;    

:delay 5s;
:foreach iname,data in=$structVLAN do={
  if ($iname="MGMT") do={
    /interface bridge vlan add bridge=$brName vlan-ids=($data->"vid") tagged=$strTagInterface untagged=$lastEthInterface comment=($data->"comment");
    :set mgmtIntrface [/interface vlan add interface=$bridgeInterface vlan-id=($data->"vid") name=$iname comment=($data->"comment")];
    /interface bridge port set [find interface=[/interface ethernet get $lastEthInterface name]] pvid=($data->"vid") comment=($data->"comment");
  } else {
    /interface bridge vlan add bridge=$brName vlan-ids=($data->"vid") tagged=$tagInterface comment=($data->"comment");  
  }
}

:foreach i in=$arrayUnTagInterface do={
    /interface bridge port set [find interface=[/interface ethernet get $i name]] ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged;
} 
:foreach i in=$tagInterface do={
    /interface bridge port set [find interface=[/interface ethernet get $i name]] ingress-filtering=yes frame-types=admit-only-vlan-tagged comment="TAG port";
} 


do {
  :set mgmtList [/interface list add name=$mgmtListName];
  /interface list member add list=$mgmtList interface=$mgmtIntrface;
  /interface list member add list=$mgmtList interface=$lastEthInterface;
  /ip neighbor discovery-settings set discover-interface-list=$mgmtList;
  /tool mac-server set allowed-interface-list=$mgmtList;
  /tool mac-server mac-winbox set allowed-interface-list=$mgmtList;
}

:do {
  /interface wireless cap set enabled=yes interfaces=$arrayWiFiInterface discovery-interfaces=$capsInterface bridge=$bridgeInterface
} on-error={ :log warning "$logPref unable to configure caps";}
