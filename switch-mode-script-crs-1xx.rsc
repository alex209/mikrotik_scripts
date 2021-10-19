:delay 2s;
:global swModel [/system routerboard get model];
:global brName  "bridge";
:global logPref "defconf:";
:global mgmtListName "MGMT_List"
#:global structVLAN {
#  "MGMT"={name="MGMT";vid=99;comment="MGMT";ipaddr="10.90.90.254";netmask="255.255.255.0";defg="10.90.90.1"};
#  "CAPs"={name="CAPs";vid=200;comment="CAPs discovery"};
#  "KPG5_consulate"={name="vlan.50";vid=50;comment="KPG5 Consulate"};
#  "KPG5_VoIP"={name="vlan.51";vid=51;comment="KPG5 VoIP"};
#  "Kvartiry"={name="vlan.52";vid=52;comment="Kvartiry"};
#  "CONS_Inet"={name="vlan.53";vid=53;comment="Consulate Intenet"};
#  "Clean_Inet"={name="vlan.55";vid=55;comment="Clean Internet"};
#  "KPG6_Internet"={name="vlan.60";vid=60;comment="KPG6 Internet"};
#  "KPG6_BUH"={name="vlan.61";vid=61;comment="KPG6 BUH VLAN"};
#  "BT_Internet"={name="vlan.62";vid=62;comment="BT Internet"}
#};
:global structVLAN {
  "MGMT"={name="MGMT";vid=99;comment="MGMT";ipaddr="10.90.90.254";netmask="255.255.255.0";defg="10.90.90.1"};
  "VLAN_20"={name="vlan.20";vid=20;comment="VLAN_20"};
  "VALN_30"={name="vlan.30";vid=30;comment="VLAN_30"};
  "VLAN_40"={name="vlan.40";vid=40;comment="VLAN_40"}
};

:global mgmtIntrface "";
:global capsInterface "";
:global bridgeInterface "";
:global mgmtList "";
:global arrayAllPort [/interface ethernet find]; # get all ethernet & sfp ports

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

# all ports to bridge interface
:global macSet 0;
:global tmpMac "";
:foreach k in=$arrayAllPort do={
  # first ethernet is found; add bridge and set mac address of the ethernet port
  :if ($macSet = 0) do={
    :set tmpMac [/interface ethernet get $k mac-address];
    :set bridgeInterface [/interface bridge add name=$brName auto-mac=no admin-mac=$tmpMac comment="defconf"];
    :set macSet 1;
  }
  # add bridge ports
  /interface bridge port add bridge=$bridgeInterface interface=$k comment="defconf" hw=yes;
}

:global firstEthInterface [/interface ethernet find default-name="ether1"]; # get first ethernet interface 
:global lastEthInterface ([interface ethernet find default-name~"ether"]->([:len [/interface ethernet find default-name~"ether"]]-1)); # get last ethernet interface
:global tagInterface [/interface ethernet find default-name~"sfp"]; # get array sfp interface
:global arrayTagInterface ($bridgeInterface,$tagInterface); # make array tagget VLAN interface
:global arrayUnTagInterface [/interface ethernet find default-name~"ether" and .id!=$lastEthInterface]; # get array ethernet interface exclude last ethernet interface 

:put "Model 1XX";

:delay 5s;
do {/interface ethernet switch set drop-if-invalid-or-src-port-not-member-of-vlan-on-ports=$arrayAllPort;
}
  
:global strAllInterface "switch1-cpu";
:foreach t in=$arrayAllPort do={
   :set strAllInterface "$strAllInterface,$[/interface get $t name]";
}

:global strTagInterface "switch1-cpu";
:foreach t in=$tagInterface do={
   :set strTagInterface "$strTagInterface,$[/interface get $t name]";
}
  
:global strMgmtIntrface "$strTagInterface,$[/interface get $lastEthInterface name]";

:foreach iname,data in=$structVLAN do={
  if ($iname="MGMT") do={
    :set mgmtIntrface [/interface vlan add interface=$bridgeInterface vlan-id=($data->"vid") name=$iname comment=($data->"comment")];
    /interface ethernet switch vlan add ports=$strMgmtIntrface vlan-id=($data->"vid") comment=($data->"comment");
    /interface ethernet switch egress-vlan-tag add tagged-ports=$strTagInterface vlan-id=($data->"vid") comment=($data->"comment");
    /interface ethernet switch ingress-vlan-translation add ports=$lastEthInterface customer-vid=0 new-customer-vid=($data->"vid") comment=($data->"comment");
  } else={
    /interface ethernet switch vlan add ports=$arrayAllPort vlan-id=($data->"vid") comment=($data->"comment");
    /interface ethernet switch egress-vlan-tag add tagged-ports=$tagInterface vlan-id=($data->"vid") comment=($data->"comment");
    #/interface ethernet switch ingress-vlan-translation add ports=$arrayUnTagInterface customer-vid=0 new-customer-vid=($data->"vid") comment=($data->"comment") disabled=yes;
  }
}

do {
  :set mgmtList [/interface list add name=$mgmtListName];
  /interface list member add list=$mgmtList interface=$mgmtIntrface;
  #/interface list member add list=$mgmtList interface=$lastEthInterface;
  /ip neighbor discovery-settings set discover-interface-list=$mgmtList;
  /tool mac-server set allowed-interface-list=$mgmtList;
  /tool mac-server mac-winbox set allowed-interface-list=$mgmtList;
  /tool romon set enabled=yes;
}

do {
  /system identity set name=("SW_".[/system routerboard get serial-number]);
}
