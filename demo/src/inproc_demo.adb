--  In-process demo: the acceptance test for semester one.
--
--    Sensor      task, publishes Reading at ~1 kHz to Temperature_Topic
--    Controller  task, publishes Command at ~10 Hz to Command_Topic
--    Main        consumes both for two seconds and prints the numbers
--
--  What it must show:
--    Command_Topic (Reliable):     Dropped = 0, every command seen in order.
--    Temperature_Topic (Best_Effort): drops under sustained rate, and the
--    last value received is the most recent one published.
--
--  Exit status is non-zero if either property fails, so CI can run it.

with Ada.Command_Line;
with Ada.Real_Time;   use Ada.Real_Time;
with Ada.Text_IO;     use Ada.Text_IO;
with Beacon;          use Beacon;
with Beacon.Topic;
with Telemetry;       use Telemetry;

procedure Inproc_Demo is

   Temp_Sub : aliased Temperature_Topic.Subscriber (Best_Effort);
   Cmd_Sub  : aliased Command_Topic.Subscriber (Reliable);

   Run_For  : constant Time_Span := Milliseconds (2000);
   Deadline : constant Time := Clock + Run_For;

   Last_Published : Natural := 0 with Atomic;
   Commands_Sent  : Natural := 0 with Atomic;

   --  Tasks activate before the first statement of this procedure, so
   --  they must not publish until the subscribers below are registered
   --  (design rule 4: registration happens before any Publish, and is
   --  not task-safe). Each task waits for Go.
   task Sensor is
      entry Go;
   end Sensor;
   task body Sensor is
      Pub : Temperature_Topic.Publisher;
      Seq : Natural := 0;
      Next : Time := Clock;
   begin
      accept Go;
      Temperature_Topic.Create_Publisher (Pub);
      while Clock < Deadline loop
         Seq := Seq + 1;
         Temperature_Topic.Publish
           (Pub, (Sensor => 1, Sequence => Seq, Temperature => 20.0 + Float (Seq mod 10)));
         Last_Published := Seq;
         Next := Next + Milliseconds (1);
         delay until Next;
      end loop;
   end Sensor;

   task Controller is
      entry Go;
   end Controller;
   task body Controller is
      Pub  : Command_Topic.Publisher;
      Next : Time := Clock;
      N    : Natural := 0;
   begin
      accept Go;
      Command_Topic.Create_Publisher (Pub);
      while Clock < Deadline loop
         N := N + 1;
         Command_Topic.Publish
           (Pub, (Kind => (if N mod 2 = 0 then Start else Stop), Target => Sensor_Id (N mod 4)));
         Commands_Sent := N;
         Next := Next + Milliseconds (100);
         delay until Next;
      end loop;
   end Controller;

   procedure Run_UC17_Demo (OK : in out Boolean);

   --  UC-17 uses a separate typed topic so the original demonstration
   --  and its publisher/subscriber state remain unchanged.
   procedure Run_UC17_Demo (OK : in out Boolean) is
      package Diagnostic_Topic is new Beacon.Topic
        (Message_Type    => Natural,
         Queue_Depth     => 1,
         Max_Subscribers => 3);

      Pub       : Diagnostic_Topic.Publisher;
      First     : aliased Diagnostic_Topic.Subscriber (Reliable);
      Middle    : aliased Diagnostic_Topic.Subscriber (Reliable);
      Last      : aliased Diagnostic_Topic.Subscriber (Reliable);
      Rejected  : Diagnostic_Topic.Delivery_Failures;
      Delivered : Boolean;
      Message   : Natural;
      Passed    : Boolean := True;
   begin
      Put_Line ("UC-17: nonblocking partial delivery (3 Reliable subscribers)");
      Diagnostic_Topic.Create_Publisher (Pub);
      Diagnostic_Topic.Create_Subscriber (First);
      Diagnostic_Topic.Create_Subscriber (Middle);
      Diagnostic_Topic.Create_Subscriber (Last);

      --  Fill all queues, then leave only the middle subscriber full.
      Diagnostic_Topic.Try_Publish (Pub, 100, Delivered, Rejected);
      Passed := Passed and Delivered;
      Diagnostic_Topic.Receive (First, Message);
      Passed := Passed and Message = 100;
      Diagnostic_Topic.Receive (Last, Message);
      Passed := Passed and Message = 100;

      Diagnostic_Topic.Try_Publish (Pub, 101, Delivered, Rejected);
      Put_Line ("  Delivered = " & Boolean'Image (Delivered));
      for I in Rejected'Range loop
         Put_Line ("  Subscriber" & I'Image & " rejected = "
                   & Boolean'Image (Rejected (I)));
      end loop;

      Passed := Passed and not Delivered;
      Passed := Passed and not Rejected (1) and Rejected (2)
        and not Rejected (3);
      Diagnostic_Topic.Receive (First, Message);
      Passed := Passed and Message = 101;
      Diagnostic_Topic.Receive (Middle, Message);
      Passed := Passed and Message = 100;
      Diagnostic_Topic.Receive (Last, Message);
      Passed := Passed and Message = 101;
      Passed := Passed and Diagnostic_Topic.Dropped (Middle) = 0;

      if Passed then
         Put_Line ("  UC-17 partial delivery ok");
      else
         Put_Line ("  FAIL: UC-17 partial delivery");
         OK := False;
      end if;
   end Run_UC17_Demo;

   Readings_Seen  : Natural := 0;
   Commands_Seen  : Natural := 0;
   Last_Reading   : Reading := (0, 0, 0.0);
   Cmd            : Command;
   Got            : Boolean;
   OK             : Boolean := True;

begin
   Temperature_Topic.Create_Subscriber (Temp_Sub);
   Command_Topic.Create_Subscriber (Cmd_Sub);
   Sensor.Go;
   Controller.Go;

   --  Consume slowly on purpose: ~100 Hz against a 1 kHz producer, so
   --  the best-effort queue overflows and we can watch it drop.
   while Clock < Deadline + Milliseconds (50) loop
      Temperature_Topic.Try_Receive (Temp_Sub, Last_Reading, Got);
      if Got then
         Readings_Seen := Readings_Seen + 1;
      end if;
      loop
         Command_Topic.Try_Receive (Cmd_Sub, Cmd, Got);
         exit when not Got;
         Commands_Seen := Commands_Seen + 1;
      end loop;
      delay 0.01;
   end loop;

   --  Producers have stopped. Drain both queues: the best-effort one to
   --  reach the newest reading, the reliable one to count everything.
   loop
      declare
         R : Reading;
      begin
         Temperature_Topic.Try_Receive (Temp_Sub, R, Got);
         exit when not Got;
         Last_Reading := R;
         Readings_Seen := Readings_Seen + 1;
      end;
   end loop;
   loop
      Command_Topic.Try_Receive (Cmd_Sub, Cmd, Got);
      exit when not Got;
      Commands_Seen := Commands_Seen + 1;
   end loop;

   Put_Line ("temperature (best-effort): published" & Last_Published'Image
             & ", received" & Readings_Seen'Image
             & ", dropped" & Temperature_Topic.Dropped (Temp_Sub)'Image
             & ", last received seq" & Last_Reading.Sequence'Image);
   Put_Line ("command (reliable):        published" & Commands_Sent'Image
             & ", received" & Commands_Seen'Image
             & ", dropped" & Command_Topic.Dropped (Cmd_Sub)'Image);

   if Command_Topic.Dropped (Cmd_Sub) /= 0 or else Commands_Seen /= Commands_Sent then
      Put_Line ("FAIL: reliable topic lost a command");
      OK := False;
   end if;
   if Temperature_Topic.Dropped (Temp_Sub) = 0 then
      Put_Line ("FAIL: best-effort never overflowed; consumer too fast for the test");
      OK := False;
   end if;
   if Last_Reading.Sequence /= Last_Published then
      Put_Line ("FAIL: best-effort did not keep the newest reading");
      OK := False;
   end if;

   New_Line;
   Run_UC17_Demo (OK);

   if OK then
      Put_Line ("inproc_demo ok");
   else
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Inproc_Demo;
