with Ada.Streams;
with Ada.Real_Time;

package body Beacon.Transport.UART is

   function Normalize_Port (Name : Serial.Port_Name)
                            return Serial.Port_Name;

   ---------------------
   -- Normalize_Port --
   ---------------------

   function Normalize_Port (Name : Serial.Port_Name)
                            return Serial.Port_Name
   is
      S : constant String := String (Name);
   begin
      --  Convert ordinary Windows COM port names to GNAT device paths.
      --  Leave explicit paths and non-COM device names unchanged.
      if S'Length > 3 and then S (S'First .. S'First + 2) = "COM" then
         for I in S'First + 3 .. S'Last loop
            if S (I) not in '0' .. '9' then
               return Name;
            end if;
         end loop;

         declare
            Number : constant Natural :=
              Natural'Value (S (S'First + 3 .. S'Last));
         begin
            if Number > 0 then
               return Serial.Name (Number);
            end if;
         end;
      end if;

      return Name;
   end Normalize_Port;

   ----------
   -- Open --
   ----------

   procedure Open
     (T         : in out UART_Transport;
      Name      : Serial.Port_Name;
      Rate      : Serial.Data_Rate := Serial.B115200;
      Bits      : Serial.Data_Bits := Serial.CS8;
      Parity    : Serial.Parity_Check := Serial.None;
      Stop_Bits : Serial.Stop_Bits_Number := Serial.One)
   is
   begin
      if T.Is_Open then
         raise Serial.Serial_Error with "UART transport already open";
      end if;

      Serial.Open (T.Port, Normalize_Port (Name));

      begin
         Serial.Set
           (Port      => T.Port,
            Rate      => Rate,
            Bits      => Bits,
            Parity    => Parity,
            Stop_Bits => Stop_Bits,
            Block     => False,
            Timeout   => 0.01);
      exception
         when others =>
            Serial.Close (T.Port);
            raise;
      end;

      T.Rx_Length := 0;
      T.Discarding := False;
      T.Is_Open := True;
   end Open;

   -----------
   -- Close --
   -----------

   procedure Close (T : in out UART_Transport) is
   begin
      if T.Is_Open then
         Serial.Close (T.Port);
         T.Is_Open := False;
      end if;

      T.Rx_Length := 0;
      T.Discarding := False;
   end Close;

   ----------
   -- Send --
   ----------

   overriding procedure Send
     (T     : in out UART_Transport;
      Frame : Wire.Byte_Array)
   is
      use Ada.Streams;
      use type Wire.Byte;

      Encoded : Stream_Element_Array
        (1 .. Stream_Element_Offset (Max_Serial_Frame)) :=
          [others => 0];

      Code_Index  : Natural := 1;
      Write_Index : Natural := 2;
      Code        : Natural := 1;
   begin
      if not T.Is_Open then
         raise Serial.Serial_Error with "UART transport not open";
      end if;

      if Frame'Length < Wire.Header_Length
        or else Frame'Length > Wire.Max_Frame
      then
         raise Constraint_Error with "Invalid Beacon frame size";
      end if;

      --  COBS encoding: reserve the first byte for a block code.
      for I in Frame'Range loop
         if Frame (I) = 0 then
            Encoded (Stream_Element_Offset (Code_Index)) :=
              Stream_Element (Code);

            Code_Index := Write_Index;
            Write_Index := Write_Index + 1;
            Code := 1;
         else
            Encoded (Stream_Element_Offset (Write_Index)) :=
              Stream_Element (Frame (I));

            Write_Index := Write_Index + 1;
            Code := Code + 1;

            if Code = 255 then
               Encoded (Stream_Element_Offset (Code_Index)) :=
                 Stream_Element (Code);

               Code_Index := Write_Index;
               Write_Index := Write_Index + 1;
               Code := 1;
            end if;
         end if;
      end loop;

      --  Finish the final block and append the packet delimiter.
      Encoded (Stream_Element_Offset (Code_Index)) :=
        Stream_Element (Code);

      Encoded (Stream_Element_Offset (Write_Index)) := 0;

      Serial.Write
        (T.Port, Encoded (1 .. Stream_Element_Offset (Write_Index)));
   end Send;

   -------------
   -- Receive --
   -------------

   overriding procedure Receive
     (T       : in out UART_Transport;
      Frame   : out Wire.Byte_Array;
      Count   : out Natural;
      Timeout : Duration)
   is
      use Ada.Streams;
      use Ada.Real_Time;
      use type Wire.Byte;

      Deadline : constant Time :=
        Clock + To_Time_Span (Duration'Max (0.0, Timeout));

      Input : Stream_Element_Array (1 .. 1);
      Last  : Stream_Element_Offset;

      Position : Natural;
      Code     : Natural;
      Next_Pos : Natural;
      Decoded  : Natural;
      Valid    : Boolean;
   begin
      if not T.Is_Open then
         raise Serial.Serial_Error with "UART transport not open";
      end if;

      Frame := [others => 0];
      Count := 0;

      loop
         Serial.Read (T.Port, Input, Last);

         if Last >= Input'First then
            declare
               B : constant Wire.Byte := Wire.Byte (Input (1));
            begin
               if B = 0 then
                  if T.Discarding then
                     T.Discarding := False;
                     T.Rx_Length := 0;

                  elsif T.Rx_Length > 0 then
                     --  Decode the completed COBS packet.
                     Position := 1;
                     Decoded := 0;
                     Valid := True;

                     while Position <= T.Rx_Length and Valid loop
                        Code := Natural (T.Rx_Buffer (Position));

                        if Code = 0
                          or else Position + Code - 1 > T.Rx_Length
                        then
                           Valid := False;
                        else
                           Next_Pos := Position + Code;

                           for I in Position + 1 .. Next_Pos - 1 loop
                              if Decoded >= Frame'Length then
                                 Valid := False;
                                 exit;
                              end if;

                              Decoded := Decoded + 1;
                              Frame (Frame'First + Decoded - 1) :=
                                T.Rx_Buffer (I);
                           end loop;

                           if Valid and then Code < 255
                             and then Next_Pos <= T.Rx_Length
                           then
                              if Decoded >= Frame'Length then
                                 Valid := False;
                              else
                                 Decoded := Decoded + 1;
                                 Frame (Frame'First + Decoded - 1) := 0;
                              end if;
                           end if;

                           Position := Next_Pos;
                        end if;
                     end loop;

                     T.Rx_Length := 0;

                     if Valid and then Decoded >= Wire.Header_Length then
                        Count := Decoded;
                        return;
                     end if;
                  end if;

               elsif not T.Discarding then
                  if T.Rx_Length < Max_Serial_Frame then
                     T.Rx_Length := T.Rx_Length + 1;
                     T.Rx_Buffer (T.Rx_Length) := B;
                  else
                     --  Ignore bytes until the next delimiter.
                     T.Discarding := True;
                     T.Rx_Length := 0;
                  end if;
               end if;
            end;
         end if;

         exit when Clock >= Deadline;
      end loop;
   end Receive;

end Beacon.Transport.UART;
