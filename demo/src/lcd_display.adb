--  Console LCD; prints a refreshed display as soon as either topic gets a message.
with Ada.Text_IO; use Ada.Text_IO;
with Beacon; use Beacon;
with Beacon.Bridge;
with Beacon.Transport.UDP;
with Demo_Config; use Demo_Config;
with Telemetry; use Telemetry;
with Telemetry.Codecs; use Telemetry.Codecs;
procedure LCD_Display is
   package Temp_In is new Beacon.Bridge
     (Temperature_Topic, Temperature_Topic_Id, Serialize_Reading, Deserialize_Reading);
   package Hum_In is new Beacon.Bridge
     (Humidity_Topic, Humidity_Topic_Id, Serialize_Humidity, Deserialize_Humidity);
   package Cmd_In is new Beacon.Bridge
     (Command_Topic, Command_Topic_Id, Serialize_Command, Deserialize_Command);
   TI, HI, CI : aliased Beacon.Transport.UDP.UDP_Transport;
   TS : aliased Temperature_Topic.Subscriber (Best_Effort);
   HS : aliased Humidity_Topic.Subscriber (Best_Effort);
   CS : aliased Command_Topic.Subscriber (Reliable);
   T : Reading;
   H : Humidity_Reading;
   C : Command;
   Got : Boolean;
   Changed : Boolean;
   Have_T, Have_H, Stopped : Boolean := False;
   Last_T, Last_H : Float := 0.0;
   Temp_Seq, Hum_Seq : Natural := 0;

   procedure Draw;

   procedure Draw is
   begin
      --  ANSI clear screen and cursor-home; standard terminals support this.
      Put (ASCII.ESC & "[2J" & ASCII.ESC & "[H");
      Put_Line ("+--------------------------------------+");
      Put_Line ("|          BEACON SYSTEM LCD           |");
      Put_Line ("+--------------------------------------+");
      if Have_T then
         Put_Line ("| Temperature: " & Last_T'Image & " C   seq" & Temp_Seq'Image);
      else
         Put_Line ("| Temperature: waiting for data");
      end if;
      if Have_H then
         Put_Line ("| Humidity:    " & Last_H'Image & " %   seq" & Hum_Seq'Image);
      else
         Put_Line ("| Humidity:    waiting for data");
      end if;
      if Stopped then
         Put_Line ("| STATUS: EMERGENCY SHUTDOWN");
      else
         Put_Line ("| STATUS: RUNNING");
      end if;
      Put_Line ("+--------------------------------------+");
      Flush;
   end Draw;
begin
   Beacon.Transport.UDP.Open (TI, Group, Temperature_Down);
   Beacon.Transport.UDP.Open (HI, Group, Humidity_Down);
   Beacon.Transport.UDP.Open (CI, Group, Command_Down);
   Temperature_Topic.Create_Subscriber (TS);
   Humidity_Topic.Create_Subscriber (HS);
   Command_Topic.Create_Subscriber (CS);
   Temp_In.Start_Ingress (TI'Access);
   Hum_In.Start_Ingress (HI'Access);
   Cmd_In.Start_Ingress (CI'Access);
   Draw;
   while not Stopped loop
      Changed := False;
      loop
         Temperature_Topic.Try_Receive (TS, T, Got);
         exit when not Got;
         Have_T := True;
         Last_T := T.Temperature;
         Temp_Seq := T.Sequence;
         Changed := True;
      end loop;
      loop
         Humidity_Topic.Try_Receive (HS, H, Got);
         exit when not Got;
         Have_H := True;
         Last_H := H.Humidity;
         Hum_Seq := H.Sequence;
         Changed := True;
      end loop;
      loop
         Command_Topic.Try_Receive (CS, C, Got);
         exit when not Got;
         if C.Kind = Stop and then C.Target = 0 then
            Stopped := True;
            Changed := True;
         end if;
      end loop;
      if Changed then
         Draw;
      else
         delay 0.01;
      end if;
   end loop;
   Temp_In.Stop;
   Hum_In.Stop;
   Cmd_In.Stop;
   Beacon.Transport.UDP.Close (TI);
   Beacon.Transport.UDP.Close (HI);
   Beacon.Transport.UDP.Close (CI);
end LCD_Display;
