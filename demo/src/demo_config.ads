with GNAT.Sockets;
package Demo_Config is
   Group : constant String := "239.255.0.1";
   Temperature_Up   : constant GNAT.Sockets.Port_Type := 5100;
   Humidity_Up      : constant GNAT.Sockets.Port_Type := 5101;
   Command_Up       : constant GNAT.Sockets.Port_Type := 5102;
   Temperature_Down : constant GNAT.Sockets.Port_Type := 5200;
   Humidity_Down    : constant GNAT.Sockets.Port_Type := 5201;
   Command_Down     : constant GNAT.Sockets.Port_Type := 5202;
   Temperature_Limit : constant Float := 30.0;
   Humidity_Limit    : constant Float := 80.0;
   Temperature_Sensor_Id : constant := 1;
   Humidity_Sensor_Id    : constant := 2;
end Demo_Config;