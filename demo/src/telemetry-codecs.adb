package body Telemetry.Codecs is

   --  Reading has Scalar_Storage_Order High_Order_First; the byte array
   --  has none. The overlay is the conversion, and this warning says so.
   pragma Warnings (Off, "overlay changes scalar storage order");

   procedure Serialize_Reading
     (Msg    : Reading;
      Buffer : out Beacon.Wire.Byte_Array;
      Last   : out Natural)
   is
      Overlay : Reading with Import, Address => Buffer (Buffer'First)'Address;
   begin
      Buffer := [others => 0];
      Overlay := Msg;
      Last := Buffer'First + Reading_Bytes - 1;
   end Serialize_Reading;

   procedure Deserialize_Reading
     (Buffer : Beacon.Wire.Byte_Array;
      Msg    : out Reading;
      Valid  : out Boolean)
   is
   begin
      Msg := (Sensor => 0, Sequence => 0, Temperature => 0.0);
      Valid := False;
      if Buffer'Length /= Reading_Bytes then
         return;
      end if;
      declare
         Overlay : Reading with Import, Address => Buffer (Buffer'First)'Address;
      begin
         if Overlay'Valid_Scalars then
            Msg := Overlay;
            Valid := True;
         end if;
      end;
   end Deserialize_Reading;

   procedure Serialize_Humidity
     (Msg : Humidity_Reading; Buffer : out Beacon.Wire.Byte_Array; Last : out Natural)
   is
      Overlay : Humidity_Reading with Import, Address => Buffer (Buffer'First)'Address;
   begin
      Buffer := [others => 0];
      Overlay := Msg;
      Last := Buffer'First + Reading_Bytes - 1;
   end Serialize_Humidity;

   procedure Deserialize_Humidity
     (Buffer : Beacon.Wire.Byte_Array; Msg : out Humidity_Reading; Valid : out Boolean)
   is
   begin
      Msg := (Sensor => 0, Sequence => 0, Humidity => 0.0);
      Valid := False;
      if Buffer'Length /= Reading_Bytes then
         return;
      end if;
      declare
         Overlay : Humidity_Reading with Import, Address => Buffer (Buffer'First)'Address;
      begin
         if Overlay'Valid_Scalars then
            Msg := Overlay;
            Valid := True;
         end if;
      end;
   end Deserialize_Humidity;

   procedure Serialize_Command
     (Msg : Command; Buffer : out Beacon.Wire.Byte_Array; Last : out Natural)
   is
      Overlay : Command with Import, Address => Buffer (Buffer'First)'Address;
   begin
      Buffer := [others => 0];
      Overlay := Msg;
      Last := Buffer'First + Command_Bytes - 1;
   end Serialize_Command;

   procedure Deserialize_Command
     (Buffer : Beacon.Wire.Byte_Array; Msg : out Command; Valid : out Boolean)
   is
   begin
      Msg := (Kind => Stop, Target => 0);
      Valid := False;
      if Buffer'Length /= Command_Bytes then
         return;
      end if;
      declare
         Overlay : Command with Import, Address => Buffer (Buffer'First)'Address;
      begin
         if Overlay'Valid_Scalars then
            Msg := Overlay;
            Valid := True;
         end if;
      end;
   end Deserialize_Command;
end Telemetry.Codecs;
