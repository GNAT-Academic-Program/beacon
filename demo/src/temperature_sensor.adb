with Ada.Command_Line;
with Ada.Numerics.Elementary_Functions;
with Ada.Text_IO; use Ada.Text_IO;
with Beacon; use Beacon;
with Beacon.Bridge;
with Beacon.Transport.UDP;
with Demo_Config; use Demo_Config;
with Telemetry; use Telemetry;
with Telemetry.Codecs; use Telemetry.Codecs;
procedure Temperature_Sensor is
   package Data_Bridge is new Beacon.Bridge
     (Local => Temperature_Topic, Topic_Id => Temperature_Topic_Id,
      Serialize => Serialize_Reading, Deserialize => Deserialize_Reading);
   package Control_Bridge is new Beacon.Bridge
     (Local => Command_Topic, Topic_Id => Command_Topic_Id,
      Serialize => Serialize_Command, Deserialize => Deserialize_Command);
   Data_Net : aliased Beacon.Transport.UDP.UDP_Transport;
   Ctrl_Net : aliased Beacon.Transport.UDP.UDP_Transport;
   Pub : Temperature_Topic.Publisher;
   Sub : aliased Command_Topic.Subscriber (Reliable);
   Cmd : Command;
   Got : Boolean;
   Running : Boolean := True;
   Seq : Natural := 0;
   Value : Float;
   Spike : constant Boolean :=
     Ada.Command_Line.Argument_Count > 0 and then Ada.Command_Line.Argument (1) = "spike";
begin
   Beacon.Transport.UDP.Open (Data_Net, Group, Temperature_Up);
   Beacon.Transport.UDP.Open (Ctrl_Net, Group, Command_Down);
   Temperature_Topic.Create_Publisher (Pub);
   Command_Topic.Create_Subscriber (Sub);
   Data_Bridge.Start_Egress (Data_Net'Access, Best_Effort);
   Control_Bridge.Start_Ingress (Ctrl_Net'Access);
   Put_Line ("TEMP SENSOR: publishing every 500 ms; spike argument triggers overheat");
   while Running loop
      loop
         Command_Topic.Try_Receive (Sub, Cmd, Got);
         exit when not Got;
         if Cmd.Kind = Stop and then (Cmd.Target = 0 or else Cmd.Target = 1) then
            Put_Line ("TEMP SENSOR: emergency STOP received");
            Running := False;
         end if;
      end loop;
      exit when not Running;
      Seq := Seq + 1;
      Value := 23.0 + 2.0 * Ada.Numerics.Elementary_Functions.Sin (Float (Seq) / 4.0);
      if Spike and then Seq >= 12 then
         Value := 45.0;
      end if;
      Temperature_Topic.Publish
        (Pub, (Sensor => 1, Sequence => Seq, Temperature => Value));
      Put_Line ("TEMP" & Seq'Image & ":" & Value'Image & " C");
      delay 0.5;
   end loop;
   Data_Bridge.Stop;
   Control_Bridge.Stop;
   Beacon.Transport.UDP.Close (Data_Net);
   Beacon.Transport.UDP.Close (Ctrl_Net);
   Put_Line ("TEMP SENSOR: stopped");
end Temperature_Sensor;
