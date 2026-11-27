--  Telemetry.Codecs: Serialize/Deserialize per message type, for the
--  bridge. Desktop only (withs Beacon.Wire).
--
--  Each pair is an overlay of the rep-claused record onto a Byte_Array
--  of exactly Reading'Size / 8 bytes. If you find yourself writing
--  shifts and masks here, stop.

with Beacon.Wire;

package Telemetry.Codecs is

   Reading_Bytes : constant := 9;  --  Reading'Size / 8; the rep clause fixes it at 72 bits
   Command_Bytes : constant := 2;

   procedure Serialize_Reading
     (Msg    : Reading;
      Buffer : out Beacon.Wire.Byte_Array;
      Last   : out Natural)
     with Pre => Buffer'Length >= Reading_Bytes;

   procedure Deserialize_Reading
     (Buffer : Beacon.Wire.Byte_Array;
      Msg    : out Reading;
      Valid  : out Boolean);

   procedure Serialize_Humidity
     (Msg : Humidity_Reading; Buffer : out Beacon.Wire.Byte_Array; Last : out Natural)
     with Pre => Buffer'Length >= Reading_Bytes;
   procedure Deserialize_Humidity
     (Buffer : Beacon.Wire.Byte_Array; Msg : out Humidity_Reading; Valid : out Boolean);

   procedure Serialize_Command
     (Msg : Command; Buffer : out Beacon.Wire.Byte_Array; Last : out Natural)
     with Pre => Buffer'Length >= Command_Bytes;
   procedure Deserialize_Command
     (Buffer : Beacon.Wire.Byte_Array; Msg : out Command; Valid : out Boolean);

end Telemetry.Codecs;
