--  Monitors both sensor topics; pressing Enter (or a threshold breach)
--  broadcasts Stop. The operator input task is aborted when an automatic
--  emergency occurs, avoiding a blocked Get_Line at process shutdown.
with Ada.Text_IO; use Ada.Text_IO;
with Beacon; use Beacon;
with Beacon.Bridge;
with Beacon.Transport.UDP;
with Demo_Config; use Demo_Config;
with Telemetry; use Telemetry;
with Telemetry.Codecs; use Telemetry.Codecs;
procedure Emergency_Alert is
   package Temp_In is new Beacon.Bridge
     (Temperature_Topic, Temperature_Topic_Id, Serialize_Reading, Deserialize_Reading);
   package Hum_In is new Beacon.Bridge
     (Humidity_Topic, Humidity_Topic_Id, Serialize_Humidity, Deserialize_Humidity);
   package Cmd_Out is new Beacon.Bridge
     (Command_Topic, Command_Topic_Id, Serialize_Command, Deserialize_Command);
   TI, HI, CO : aliased Beacon.Transport.UDP.UDP_Transport;
   TS : aliased Temperature_Topic.Subscriber (Best_Effort);
   HS : aliased Humidity_Topic.Subscriber (Best_Effort);
   Pub : Command_Topic.Publisher;
   T : Reading;
   H : Humidity_Reading;
   Got : Boolean;
   Alarm : Boolean := False;

   protected Operator_Signal is
      procedure Trigger;
      function Pressed return Boolean;
   private
      Activated : Boolean := False;
   end Operator_Signal;
   protected body Operator_Signal is
      procedure Trigger is
      begin
         Activated := True;
      end Trigger;
      function Pressed return Boolean is
      begin
         return Activated;
      end Pressed;
   end Operator_Signal;

   task Operator_Input;
   task body Operator_Input is
      Line : String (1 .. 80);
      Last : Natural;
   begin
      Get_Line (Line, Last);
      Operator_Signal.Trigger;
   end Operator_Input;
begin
   Beacon.Transport.UDP.Open (TI, Group, Temperature_Down);
   Beacon.Transport.UDP.Open (HI, Group, Humidity_Down);
   Beacon.Transport.UDP.Open (CO, Group, Command_Up);
   Temperature_Topic.Create_Subscriber (TS);
   Humidity_Topic.Create_Subscriber (HS);
   Command_Topic.Create_Publisher (Pub);
   Temp_In.Start_Ingress (TI'Access);
   Hum_In.Start_Ingress (HI'Access);
   Cmd_Out.Start_Egress (CO'Access, Reliable);
   Put_Line ("EMERGENCY MONITOR: Enter = E-STOP");
   Put_Line ("Thresholds: >" & Temperature_Limit'Image & " C, >" & Humidity_Limit'Image & " %");
   while not Alarm loop
      if Operator_Signal.Pressed then
         Put_Line ("EMERGENCY: operator E-STOP");
         Alarm := True;
      end if;
      loop
         Temperature_Topic.Try_Receive (TS, T, Got);
         exit when not Got;
         if T.Temperature > Temperature_Limit then
            Put_Line ("EMERGENCY: over-temperature " & T.Temperature'Image);
            Alarm := True;
         end if;
      end loop;
      loop
         Humidity_Topic.Try_Receive (HS, H, Got);
         exit when not Got;
         if H.Humidity > Humidity_Limit then
            Put_Line ("EMERGENCY: high humidity " & H.Humidity'Image);
            Alarm := True;
         end if;
      end loop;
      exit when Alarm;
      delay 0.01;
   end loop;
   --  Repetition improves odds of delivery on a lossy UDP network,
   --  but does NOT make this a safety-rated emergency-stop protocol.
   for Attempt in 1 .. 10 loop
      Command_Topic.Publish (Pub, (Kind => Stop, Target => 0));
      delay 0.1;
   end loop;
   abort Operator_Input;
   Cmd_Out.Stop;
   Temp_In.Stop;
   Hum_In.Stop;
   Beacon.Transport.UDP.Close (TI);
   Beacon.Transport.UDP.Close (HI);
   Beacon.Transport.UDP.Close (CO);
   Put_Line ("EMERGENCY: STOP broadcast sent; device acknowledgments not verified");
end Emergency_Alert;
