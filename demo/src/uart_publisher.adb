
--  UART demo, sending side.
--     uart_publisher [serial_port] [count]
--  Example: uart_publisher COM5 200
--  Run uart_subscriber on the paired serial port.

with Ada.Command_Line;       use Ada.Command_Line;
with Ada.Text_IO;            use Ada.Text_IO;
with Beacon;                 use Beacon;
with Beacon.Bridge;
with Beacon.Transport.UART;
with Telemetry;              use Telemetry;
with Telemetry.Codecs;       use Telemetry.Codecs;

procedure UART_Publisher is

   package Temperature_Bridge is new Beacon.Bridge
     (Local       => Temperature_Topic,
      Topic_Id    => Temperature_Topic_Id,
      Serialize   => Serialize_Reading,
      Deserialize => Deserialize_Reading);

   Port_Name : constant String :=
     (if Argument_Count >= 1 then Argument (1) else "COM5");

   Count : constant Positive :=
     (if Argument_Count >= 2 then Positive'Value (Argument (2)) else 200);

   Net : aliased Beacon.Transport.UART.UART_Transport;
   Pub : Temperature_Topic.Publisher;

begin
   Beacon.Transport.UART.Open
  (Net, Beacon.Transport.UART.Serial.Port_Name (Port_Name));
   Temperature_Bridge.Start_Egress (Net'Access, Best_Effort);
   Temperature_Topic.Create_Publisher (Pub);

   Put_Line ("uart_publisher: " & Port_Name & "," & Count'Image & " readings");

   for Seq in 1 .. Count loop
      Temperature_Topic.Publish
        (Pub, (Sensor => 7, Sequence => Seq, Temperature => Float (Seq) / 10.0));
      delay 0.001;
   end loop;

   delay 0.2;
   Temperature_Bridge.Stop;
   Beacon.Transport.UART.Close (Net);
   Put_Line ("uart_publisher: done");
end UART_Publisher;
