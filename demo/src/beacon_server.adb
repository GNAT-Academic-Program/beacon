--  Raspberry Pi hub: three ingress channels -> local typed topics -> three egress channels.
--  Run this before any endpoints, and keep it running until Ctrl+C.
with Ada.Text_IO; use Ada.Text_IO;
with Beacon; use Beacon;
with Beacon.Bridge;
with Beacon.Transport.UDP;
with Demo_Config; use Demo_Config;
with Telemetry; use Telemetry;
with Telemetry.Codecs; use Telemetry.Codecs;
procedure Beacon_Server is
   package Temp_In is new Beacon.Bridge
     (Temperature_Topic, Temperature_Topic_Id, Serialize_Reading, Deserialize_Reading);
   package Temp_Out is new Beacon.Bridge
     (Temperature_Topic, Temperature_Topic_Id, Serialize_Reading, Deserialize_Reading);
   package Hum_In is new Beacon.Bridge
     (Humidity_Topic, Humidity_Topic_Id, Serialize_Humidity, Deserialize_Humidity);
   package Hum_Out is new Beacon.Bridge
     (Humidity_Topic, Humidity_Topic_Id, Serialize_Humidity, Deserialize_Humidity);
   package Cmd_In is new Beacon.Bridge
     (Command_Topic, Command_Topic_Id, Serialize_Command, Deserialize_Command);
   package Cmd_Out is new Beacon.Bridge
     (Command_Topic, Command_Topic_Id, Serialize_Command, Deserialize_Command);
   TI, TO_Net, HI, HO, CI, CO : aliased Beacon.Transport.UDP.UDP_Transport;
begin
   Beacon.Transport.UDP.Open (TI, Group, Temperature_Up);
   Beacon.Transport.UDP.Open (TO_Net, Group, Temperature_Down);
   Beacon.Transport.UDP.Open (HI, Group, Humidity_Up);
   Beacon.Transport.UDP.Open (HO, Group, Humidity_Down);
   Beacon.Transport.UDP.Open (CI, Group, Command_Up);
   Beacon.Transport.UDP.Open (CO, Group, Command_Down);

   --  Start outgoing local subscribers before receiving incoming traffic.
   Temp_Out.Start_Egress (TO_Net'Access, Best_Effort);
   Hum_Out.Start_Egress (HO'Access, Best_Effort);
   Cmd_Out.Start_Egress (CO'Access, Reliable);
   Temp_In.Start_Ingress (TI'Access);
   Hum_In.Start_Ingress (HI'Access);
   Cmd_In.Start_Ingress (CI'Access);
   Put_Line ("BEACON HUB: running on " & Group);
   Put_Line ("  temperature: 5100 -> 5200");
   Put_Line ("  humidity:    5101 -> 5201");
   Put_Line ("  emergency:   5102 -> 5202");
   loop
      delay 60.0;
      Put_Line ("BEACON HUB: active");
   end loop;
end Beacon_Server;
