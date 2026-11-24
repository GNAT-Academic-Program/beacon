--  Tests for UC-16: the topic owns the subscriber queues, and a subscriber
--  holds only a slot number. A subscriber that leaves scope can no longer
--  leave a dangling pointer behind in the topic.
--
--  Every test uses its own topic instance, because registrations are
--  never released.

with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;
with Beacon; use Beacon;
with Beacon.Topic;

procedure Unchecked_Access_Tests is

   Depth    : constant Positive := 2;
   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Name : String);
   procedure Test_Unregistered_And_Register;
   procedure Test_Scope_Exit_Best_Effort;
   procedure Test_Scope_Exit_Reliable;
   procedure Test_Mixed_Modes;
   procedure Test_Registry_Full;

   procedure Check (Condition : Boolean; Name : String) is
   begin
      if Condition then
         Put_Line ("  ok   " & Name);
      else
         Put_Line ("  FAIL " & Name);
         Failures := Failures + 1;
      end if;
   end Check;

   --  A: an unregistered handle is safe to query, then registration works.
   procedure Test_Unregistered_And_Register is
      package T is new Beacon.Topic
        (Message_Type    => Natural,
         Queue_Depth     => Depth,
         Max_Subscribers => 2);

      S : T.Subscriber (Reliable);
   begin
      Put_Line ("A: unregistered queries and registration");
      Check (not T.Is_Registered (S), "new subscriber is not registered");
      Check (T.Pending (S) = 0, "unregistered Pending is 0");
      Check (T.Dropped (S) = 0, "unregistered Dropped is 0");
      Check (T.Subscriber_Count = 0, "topic starts with no subscribers");

      T.Create_Subscriber (S);

      Check (T.Is_Registered (S), "subscriber is registered");
      Check (T.Subscriber_Count = 1, "topic count increased by one");
      Check (T.Pending (S) = 0, "new queue is empty");
   end Test_Unregistered_And_Register;

   --  B: a Best_Effort handle leaves scope; the topic keeps working.
   procedure Test_Scope_Exit_Best_Effort is
      package T is new Beacon.Topic
        (Message_Type    => Natural,
         Queue_Depth     => Depth,
         Max_Subscribers => 1);

      Pub       : T.Publisher;
      Delivered : Boolean;
      All_True  : Boolean := True;
   begin
      Put_Line ("B: Best_Effort subscriber leaves scope");
      T.Create_Publisher (Pub);

      declare
         Temporary : T.Subscriber (Best_Effort);
      begin
         T.Create_Subscriber (Temporary);
      end;

      for I in 1 .. Depth + 3 loop
         T.Try_Publish (Pub, I, Delivered);
         All_True := All_True and Delivered;
      end loop;

      Check (All_True, "every Try_Publish is delivered after scope exit");
      Check (T.Subscriber_Count = 1, "abandoned slot is still registered");
   end Test_Scope_Exit_Best_Effort;

   --  C: a Reliable handle leaves scope; its queue fills, then refuses.
   procedure Test_Scope_Exit_Reliable is
      package T is new Beacon.Topic
        (Message_Type    => Natural,
         Queue_Depth     => Depth,
         Max_Subscribers => 1);

      Pub           : T.Publisher;
      Delivered     : Boolean;
      First_Ok      : Boolean := True;
      Later_Refused : Boolean := True;
   begin
      Put_Line ("C: Reliable subscriber leaves scope");
      T.Create_Publisher (Pub);

      declare
         Temporary : T.Subscriber (Reliable);
      begin
         T.Create_Subscriber (Temporary);
      end;

      for I in 1 .. Depth loop
         T.Try_Publish (Pub, I, Delivered);
         First_Ok := First_Ok and Delivered;
      end loop;

      for I in 1 .. 3 loop
         T.Try_Publish (Pub, I, Delivered);
         Later_Refused := Later_Refused and not Delivered;
      end loop;

      Check (First_Ok, "first Depth messages are accepted");
      Check (Later_Refused, "later messages are refused, not blocked");
      Check (T.Subscriber_Count = 1, "abandoned slot is still registered");
   end Test_Scope_Exit_Reliable;

   --  D: one array of queues serves two modes, and each handle reaches
   --  its own queue.
   procedure Test_Mixed_Modes is
      package T is new Beacon.Topic
        (Message_Type    => Natural,
         Queue_Depth     => 2,
         Max_Subscribers => 2);

      Pub       : T.Publisher;
      Rel       : T.Subscriber (Reliable);
      Best      : T.Subscriber (Best_Effort);
      Delivered : Boolean;
      Got       : Natural;
   begin
      Put_Line ("D: Reliable and Best_Effort share one topic");
      T.Create_Publisher (Pub);
      T.Create_Subscriber (Rel);
      T.Create_Subscriber (Best);

      T.Try_Publish (Pub, 1, Delivered);
      Check (Delivered, "message 1 delivered to both");
      T.Try_Publish (Pub, 2, Delivered);
      Check (Delivered, "message 2 delivered to both");
      T.Try_Publish (Pub, 3, Delivered);
      Check (not Delivered, "message 3 refused by the full Reliable queue");

      Check (T.Pending (Rel) = 2, "Reliable queue still holds 2");
      Check (T.Pending (Best) = 2, "Best_Effort queue holds 2");
      Check (T.Dropped (Rel) = 0, "Reliable never drops");
      Check (T.Dropped (Best) = 1, "Best_Effort dropped exactly one");

      T.Receive (Rel, Got);
      Check (Got = 1, "Reliable receives 1 first");
      T.Receive (Rel, Got);
      Check (Got = 2, "Reliable receives 2 next");

      T.Receive (Best, Got);
      Check (Got = 2, "Best_Effort oldest (1) was dropped");
      T.Receive (Best, Got);
      Check (Got = 3, "Best_Effort receives 3 last");
   end Test_Mixed_Modes;

   --  E: registering past Max_Subscribers is rejected and changes nothing.
   --  This needs contracts (-gnata) or range checks to be enabled.
   procedure Test_Registry_Full is
      package T is new Beacon.Topic
        (Message_Type    => Natural,
         Queue_Depth     => Depth,
         Max_Subscribers => 1);

      First  : T.Subscriber (Reliable);
      Second : T.Subscriber (Reliable);
      Raised : Boolean := False;
   begin
      Put_Line ("E: registration past Max_Subscribers");
      T.Create_Subscriber (First);

      begin
         T.Create_Subscriber (Second);
      exception
         when others =>
            Raised := True;
      end;

      Check (Raised, "extra registration is rejected");
      Check (T.Subscriber_Count = 1, "count is unchanged");
      Check (not T.Is_Registered (Second), "rejected handle stays unregistered");
   end Test_Registry_Full;

begin
   Put_Line ("Unchecked access tests (UC-16)");
   Test_Unregistered_And_Register;
   Test_Scope_Exit_Best_Effort;
   Test_Scope_Exit_Reliable;
   Test_Mixed_Modes;
   Test_Registry_Full;

   if Failures = 0 then
      Put_Line ("unchecked_access_tests ok");
   else
      Put_Line ("unchecked_access_tests FAILED");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Unchecked_Access_Tests;