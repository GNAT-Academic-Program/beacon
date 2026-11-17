
--  Beacon.Transport.UART: serial transport for Beacon.Wire frames.
--  Uses COBS framing with a zero-byte packet delimiter.
--
--  The transport returns complete Beacon.Wire frames to Beacon.Bridge.
--  Incomplete received frames are retained across Receive timeouts.

with GNAT.Serial_Communications;

package Beacon.Transport.UART is

   package Serial renames GNAT.Serial_Communications;

   type UART_Transport is limited new Transport with private;

   procedure Open
     (T         : in out UART_Transport;
      Name      : Serial.Port_Name;
      Rate      : Serial.Data_Rate := Serial.B115200;
      Bits      : Serial.Data_Bits := Serial.CS8;
      Parity    : Serial.Parity_Check := Serial.None;
      Stop_Bits : Serial.Stop_Bits_Number := Serial.One);

   procedure Close (T : in out UART_Transport);

   overriding procedure Send
     (T     : in out UART_Transport;
      Frame : Wire.Byte_Array);

   overriding procedure Receive
     (T       : in out UART_Transport;
      Frame   : out Wire.Byte_Array;
      Count   : out Natural;
      Timeout : Duration);

private

   --  Maximum COBS-encoded frame plus delimiter.
   Max_Serial_Frame : constant := Wire.Max_Frame
     + (Wire.Max_Frame / 254) + 2;

   type UART_Transport is limited new Transport with record
      Port       : Serial.Serial_Port;
      Is_Open    : Boolean := False;
      Rx_Buffer  : Wire.Byte_Array (1 .. Max_Serial_Frame) :=
        [others => 0];
      Rx_Length  : Natural := 0;
      Discarding : Boolean := False;
   end record;

end Beacon.Transport.UART;
