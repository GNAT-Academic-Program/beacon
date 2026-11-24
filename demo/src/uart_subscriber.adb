
--  UART demo, receiving side.
--     uart_subscriber [serial_port] [seconds]
--  Example: uart_subscriber COM6 5
--  Run uart_publisher on the paired serial port.

with Ada.Command_Line;       use Ada.Command_Line;
with Ada.Real_Time;          use Ada.Real_Time;
with Ada.Text_IO;            use Ada.Text_IO;
with Beacon;                 use Beacon;
with Beacon.Bridge;
with Beacon.Transport.UART;
with Telemetry;              use Telemetry;
with Telemetry.Codecs;       use Telemetry.Codecs;

procedure UART_Subscriber is

   package Temperature_Bridge is new Beacon.Bridge
     (Local       => Temperature_Topic,
      Topic_Id    => Temperature_Topic_Id,
      Serialize   => Serialize_Reading,
      Deserialize => Deserialize_Reading);

   Port_Name : constant String :=
     (if Argument_Count >= 1 then Argument (1) else "COM6");

   Secs : constant Positive :=
     (if Argument_Count >= 2 then Positive'Value (Argument (2)) else 5);

   Net : aliased Beacon.Transport.UART.UART_Transport;
   Sub : aliased Temperature_Topic.Subscriber (Best_Effort);

   Deadline    : constant Time := Clock + Seconds (Secs);
   Next_Report : Time := Clock + Milliseconds (500);

   R    : Reading;
   Got  : Boolean;
   Seen : Natural := 0;
   Last : Natural := 0;

begin
   Beacon.Transport.UART.Open
     (Net, Beacon.Transport.UART.Serial.Port_Name (Port_Name));

   Temperature_Topic.Create_Subscriber (Sub);
   Temperature_Bridge.Start_Ingress (Net'Access);

   Put_Line ("uart_subscriber: listening on " & Port_Name);

   while Clock < Deadline loop
      Temperature_Topic.Try_Receive (Sub, R, Got);
      if Got then
         Seen := Seen + 1;
         Last := R.Sequence;
      else
         delay 0.001;
      end if;

      if Clock >= Next_Report then
         Put_Line ("  received" & Seen'Image & ", last seq" & Last'Image
                   & ", dropped locally" & Temperature_Topic.Dropped (Sub)'Image
                   & ", rejected frames" & Temperature_Bridge.Rejected_Frames'Image
                   & ", sequence gaps" & Temperature_Bridge.Sequence_Gaps'Image);
         Next_Report := Next_Report + Milliseconds (500);
      end if;
   end loop;

   Temperature_Bridge.Stop;
   Beacon.Transport.UART.Close (Net);

   Put_Line ("uart_subscriber: done," & Seen'Image & " readings");
end UART_Subscriber;
