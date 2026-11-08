with Beacon.Topic;
with System;
package Telemetry is
   type Sensor_Id is range 0 .. 255 with Size => 8;

   --  Preserves the original network demo's temperature representation.
   type Reading is record
      Sensor      : Sensor_Id;
      Sequence    : Natural;
      Temperature : Float;
   end record
     with Size                 => 72,
          Bit_Order            => System.High_Order_First,
          Scalar_Storage_Order => System.High_Order_First;
   for Reading use record
      Sensor      at 0 range 0 .. 7;
      Sequence    at 1 range 0 .. 31;
      Temperature at 5 range 0 .. 31;
   end record;

   type Humidity_Reading is record
      Sensor   : Sensor_Id;
      Sequence : Natural;
      Humidity : Float;
   end record
     with Size                 => 72,
          Bit_Order            => System.High_Order_First,
          Scalar_Storage_Order => System.High_Order_First;
   for Humidity_Reading use record
      Sensor   at 0 range 0 .. 7;
      Sequence at 1 range 0 .. 31;
      Humidity at 5 range 0 .. 31;
   end record;

   type Command_Kind is (Start, Stop, Reset);
   for Command_Kind use (Start => 1, Stop => 2, Reset => 3);
   for Command_Kind'Size use 8;
   type Command is record
      Kind   : Command_Kind;
      Target : Sensor_Id;
   end record
     with Size                 => 16,
          Bit_Order            => System.High_Order_First,
          Scalar_Storage_Order => System.High_Order_First;
   for Command use record
      Kind   at 0 range 0 .. 7;
      Target at 1 range 0 .. 7;
   end record;

   package Temperature_Topic is new Beacon.Topic
     (Message_Type => Reading, Queue_Depth => 32);
   package Humidity_Topic is new Beacon.Topic
     (Message_Type => Humidity_Reading, Queue_Depth => 32);
   package Command_Topic is new Beacon.Topic
     (Message_Type => Command, Queue_Depth => 8);

   Temperature_Topic_Id : constant := 1;
   Command_Topic_Id     : constant := 2; --  Kept for original demo compatibility
   Humidity_Topic_Id    : constant := 3;
end Telemetry;
