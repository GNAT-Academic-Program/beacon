with Ada.Command_Line;
with Ada.Numerics.Elementary_Functions;
with Ada.Text_IO; use Ada.Text_IO;
with Beacon; use Beacon;
with Beacon.Bridge;
with Beacon.Transport.UDP;
with Demo_Config; use Demo_Config;
with Telemetry; use Telemetry;
with Telemetry.Codecs; use Telemetry.Codecs;
procedure Humidity_Sensor is
   package Data_Bridge is new Beacon.Bridge
     (Local => Humidity_Topic, Topic_Id => Humidity_Topic_Id,
      Serialize => Serialize_Humidity, Deserialize => Deserialize_Humidity);
   package Control_Bridge is new Beacon.Bridge
     (Local => Command_Topic, Topic_Id => Command_Topic_Id,
      Serialize => Serialize_Command, Deserialize => Deserialize_Command);
   Data_Net : aliased Beacon.Transport.UDP.UDP_Transport;
   Ctrl_Net : aliased Beacon.Transport.UDP.UDP_Transport;
   Pub : Humidity_Topic.Publisher;
   Sub : aliased Command_Topic.Subscriber (Reliable);
   Cmd : Command;
   Got : Boolean;
   Running : Boolean := True;
   Seq : Natural := 0;
   Value : Float;
   Spike : constant Boolean :=
     Ada.Command_Line.Argument_Count > 0 and then Ada.Command_Line.Argument (1) = "spike";
begin
   Beacon.Transport.UDP.Open (Data_Net, Group, Humidity_Up);
   Beacon.Transport.UDP.Open (Ctrl_Net, Group, Command_Down);
   Humidity_Topic.Create_Publisher (Pub);
   Command_Topic.Create_Subscriber (Sub);
   Data_Bridge.Start_Egress (Data_Net'Access, Best_Effort);
   Control_Bridge.Start_Ingress (Ctrl_Net'Access);
   Put_Line ("HUMIDITY SENSOR: publishing every 700 ms; spike argument triggers alert");
   while Running loop
      loop
         Command_Topic.Try_Receive (Sub, Cmd, Got);
         exit when not Got;
         if Cmd.Kind = Stop and then (Cmd.Target = 0 or else Cmd.Target = 2) then
            Put_Line ("HUMIDITY SENSOR: emergency STOP received");
            Running := False;
         end if;
      end loop;
      exit when not Running;
      Seq := Seq + 1;
      Value := 50.0 + 8.0 * Ada.Numerics.Elementary_Functions.Sin (Float (Seq) / 5.0);
      if Spike and then Seq >= 12 then
         Value := 95.0;
      end if;
      Humidity_Topic.Publish
        (Pub, (Sensor => 2, Sequence => Seq, Humidity => Value));
      Put_Line ("HUMIDITY" & Seq'Image & ":" & Value'Image & " %");
      delay 0.7;
   end loop;
   Data_Bridge.Stop;
   Control_Bridge.Stop;
   Beacon.Transport.UDP.Close (Data_Net);
   Beacon.Transport.UDP.Close (Ctrl_Net);
   Put_Line ("HUMIDITY SENSOR: stopped");
end Humidity_Sensor;
