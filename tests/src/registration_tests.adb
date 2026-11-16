with Ada.Assertions;
with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;
with Beacon;      use Beacon;
with Beacon.Topic;

procedure Registration_Tests is
   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Name : String);
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if Condition then
         Put_Line ("  ok    " & Name);
      else
         Put_Line ("  FAIL  " & Name);
         Failures := Failures + 1;
      end if;
   end Check;

   procedure Check_Race (Capacity : Positive);
   procedure Check_Race (Capacity : Positive) is
      package T is new Beacon.Topic (Natural, 1, Capacity);
      type Subscriber_Array is array (1 .. 3) of aliased T.Subscriber (Best_Effort);
      Subs : Subscriber_Array;
      Pub  : T.Publisher;

      protected Results is
         procedure Arrive;
         entry Start;
         procedure Record_Result (Accepted : Boolean);
         entry Finished (Accepted : out Natural; Rejected : out Natural);
      private
         Ready     : Natural := 0;
         Completed : Natural := 0;
         Successes : Natural := 0;
         Refusals  : Natural := 0;
      end Results;

      protected body Results is
         procedure Arrive is
         begin
            Ready := Ready + 1;
         end Arrive;

         entry Start when Ready = 3 is
         begin
            null;
         end Start;

         procedure Record_Result (Accepted : Boolean) is
         begin
            Completed := Completed + 1;
            if Accepted then
               Successes := Successes + 1;
            else
               Refusals := Refusals + 1;
            end if;
         end Record_Result;

         entry Finished (Accepted : out Natural; Rejected : out Natural)
           when Completed = 3
         is
         begin
            Accepted := Successes;
            Rejected := Refusals;
         end Finished;
      end Results;

      task type Worker (Index : Positive);
      task body Worker is
      begin
         Results.Arrive;
         Results.Start;
         begin
            T.Create_Subscriber (Subs (Index));
            Results.Record_Result (True);
         exception
            when Ada.Assertions.Assertion_Error =>
               Results.Record_Result (False);
         end;
      end Worker;

      Accepted : Natural;
      Rejected : Natural;
      Msg      : Natural;
      Got      : Boolean;
   begin
      --  These tasks finish before Subs leaves scope.
      declare
         First  : Worker (1);
         Second : Worker (2);
         Third  : Worker (3);
      begin
         Results.Finished (Accepted, Rejected);
      end;
      Check (Accepted = Capacity and then Rejected = 3 - Capacity,
             "concurrent registration respects capacity" & Capacity'Image);
      Check (T.Subscriber_Count = Capacity, "count matches successful registrations");
      T.Create_Publisher (Pub);
      T.Publish (Pub, 42);
      for S of Subs loop
         if T.Is_Registered (S) then
            T.Try_Receive (S, Msg, Got);
            Check (Got and then Msg = 42, "registered subscriber receives publication");
            T.Try_Receive (S, Msg, Got);
            Check (not Got, "subscriber receives publication once");
         end if;
      end loop;
   end Check_Race;

   procedure Check_Rejections (Use_Try : Boolean);
   procedure Check_Rejections (Use_Try : Boolean) is
      package T is new Beacon.Topic (Natural, 1, 2);
      First : aliased T.Subscriber (Best_Effort);
      Late  : aliased T.Subscriber (Best_Effort);
      Pub   : T.Publisher;
      Other : T.Publisher;
      Sent  : Boolean;
   begin
      T.Create_Publisher (Pub);
      begin
         T.Create_Publisher (Other);
         Check (False, "second publisher rejected");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check (not T.Is_Created (Other), "second publisher remains uncreated");
      end;
      if Use_Try then
         --  Even a publication with no subscribers closes registration.
         T.Try_Publish (Pub, 1, Sent);
         Check (Sent, "zero-subscriber Try_Publish succeeds");
      else
         T.Create_Subscriber (First);
         begin
            T.Create_Subscriber (First);
            Check (False, "duplicate registration rejected");
         exception
            when Ada.Assertions.Assertion_Error =>
               Check (T.Subscriber_Count = 1, "duplicate leaves count unchanged");
         end;
         T.Publish (Pub, 1);
      end if;
      begin
         T.Create_Subscriber (Late);
         Check (False, "registration after publication rejected");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check (not T.Is_Registered (Late), "late subscriber remains unregistered");
            Check (T.Subscriber_Count = (if Use_Try then 0 else 1),
                   "late registration leaves count unchanged");
      end;
   end Check_Rejections;
begin
   Put_Line ("Beacon.Topic registration tests");
   Check_Race (3);
   Check_Race (2);
   Check_Rejections (False);
   Check_Rejections (True);
   if Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Registration_Tests;
