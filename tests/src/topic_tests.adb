--  Tests for Beacon.Topic. Owner: validation engineer. Green by Week 8.
--  The Week 8 review question, verbatim: fill a reliable queue past
--  capacity and verify the documented behavior actually occurs.
--  UC-17 tests cover partial delivery and bounded rejection diagnostics.

with Ada.Command_Line;
with Ada.Text_IO;  use Ada.Text_IO;
with Beacon;       use Beacon;
with Beacon.Topic;
with Ada.Real_Time;   use Ada.Real_Time;

procedure Topic_Tests is

   Failures : Natural := 0;

   procedure Check (Cond : Boolean; Name : String);
   procedure Check (Cond : Boolean; Name : String) is
   begin
      if Cond then
         Put_Line ("  ok    " & Name);
      else
         Put_Line ("  FAIL  " & Name);
         Failures := Failures + 1;
      end if;
   end Check;

   type Reading is record
      Id    : Natural;
      Value : Float;
   end record;

   Depth : constant := 3;
   package T is new Beacon.Topic
     (Message_Type => Reading, Queue_Depth => Depth, Max_Subscribers => 2);

   Pub        : T.Publisher;
   Rel        : aliased T.Subscriber (Reliable);
   Best       : aliased T.Subscriber (Best_Effort);
   Msg        : Reading;
   Got        : Boolean;
   Delivered  : Boolean;
   Rejections : T.Delivery_Failures;

   package T_Unused is new Beacon.Topic
     (Message_Type    => Reading,
      Queue_Depth     => 1,
      Max_Subscribers => 3);

   Pub_Unused       : T_Unused.Publisher;
   Sub_Unused       : aliased T_Unused.Subscriber (Reliable);
   Unused_Failures  : T_Unused.Delivery_Failures;
   Unused_Delivered : Boolean;

   --  UC-17: partial delivery across three subscribers.
   package T_Partial is new Beacon.Topic
     (Message_Type    => Reading,
      Queue_Depth     => 1,
      Max_Subscribers => 3);

   Partial_Pub       : T_Partial.Publisher;
   Partial_First     : aliased T_Partial.Subscriber (Reliable);
   Partial_Middle    : aliased T_Partial.Subscriber (Reliable);
   Partial_Last      : aliased T_Partial.Subscriber (Reliable);
   Partial_Failures  : T_Partial.Delivery_Failures;
   Partial_Delivered : Boolean;

begin
   Put_Line ("Beacon.Topic tests");

   T.Create_Publisher (Pub);
   T.Create_Subscriber (Rel);
   T.Create_Subscriber (Best);
   Check (T.Subscriber_Count = 2, "two subscribers registered");

   --  Fan-out: one publish, both receive the same typed value.
   T.Publish (Pub, (Id => 1, Value => 1.5));
   T.Receive (Rel, Msg);
   Check (Msg.Id = 1, "reliable subscriber receives typed value");
   T.Receive (Best, Msg);
   Check (Msg.Value = 1.5, "best-effort subscriber receives typed value");

   --  Fill both to capacity without draining.
   for I in 1 .. Depth loop
      T.Publish (Pub, (Id => I, Value => 0.0));
   end loop;
   Check (T.Pending (Rel) = Depth and then T.Pending (Best) = Depth,
          "both queues full");

   --  Overflow: Try_Publish must NOT block, must report the reliable
   --  refusal, and the best-effort side must drop its oldest.
   T.Try_Publish (Pub, (Id => 99, Value => 0.0), Delivered);
   Check (not Delivered, "reliable full: Try_Publish reports not delivered");
   Check (T.Pending (Rel) = Depth and then T.Dropped (Rel) = 0,
          "reliable: nothing dropped, nothing added");
   Check (T.Dropped (Best) = 1, "best-effort: exactly one drop counted");
   T.Receive (Best, Msg);
   Check (Msg.Id = 2, "best-effort: oldest (1) gone, 2 is now first");

   --  UC-17: identify the full Reliable subscriber while Best_Effort
   --  delivery continues. This uses the queues filled above.
   T.Try_Publish
     (Pub, (Id => 100, Value => 0.0), Delivered, Rejections);

   Check (not Delivered, "bitmap: reports incomplete delivery");
   Check (Rejections (1), "bitmap: reliable subscriber 1 rejected");
   Check (not Rejections (2), "bitmap: best-effort subscriber 2 accepted");
   Check (T.Pending (Rel) = Depth,
          "bitmap: reliable queue remains at capacity");
   Check (T.Dropped (Rel) = 0,
          "bitmap: reliable subscriber never drops");
   Check (T.Dropped (Best) = 1,
          "bitmap: best-effort accepts without another drop");

   --  Reliable never lost anything: drain and check order.
   for Expected in 1 .. Depth loop
      T.Receive (Rel, Msg);
      if Msg.Id /= Expected then
         Failures := Failures + 1;
         Put_Line ("  FAIL  reliable order");
      end if;
   end loop;
   T.Try_Receive (Rel, Msg, Got);
   Check (not Got, "reliable drained, Try_Receive says empty");

   --  UC-18: Receive with timeout.
   --  Rel was just drained above, so its queue is empty here.

   --  Zero timeout on an empty queue behaves like Try_Receive.
   T.Receive (Rel, Msg, 0.0, Got);
   Check (not Got and then T.Pending (Rel) = 0,
          "UC-18: zero timeout on empty queue returns Success = False");

   --  Timeout expires on an empty queue: no message taken,
   --  and it waited at least the requested time.
   declare
      Start   : constant Time := Clock;
      Elapsed : Time_Span;
   begin
      T.Receive (Rel, Msg, 0.05, Got);
      Elapsed := Clock - Start;
      Check (not Got, "UC-18: timeout expires, Success = False");
      Check (T.Pending (Rel) = 0, "UC-18: timeout leaves queue unchanged");
      Check (Elapsed >= Milliseconds (50),
             "UC-18: waited at least the requested timeout");
      Check (Elapsed < Milliseconds (1_000),
             "UC-18: returned promptly after the timeout");
   end;

   --  SNFR-2 / UNFR-2: a timed Receive returns within Tolerance after
   --  its requested timeout. Repeated to catch timer jitter; the worst
   --  case is printed so the tolerance can be checked against real runs.
   declare
      Timeout   : constant Duration  := 0.02;
      Tolerance : constant Time_Span := Milliseconds (30);
      Runs      : constant Natural   := 20;
      Count     : Natural   := 0;
      Worst     : Time_Span := Time_Span_Zero;
      Start     : Time;
      Late      : Time_Span;
   begin
      while Count < Runs loop
         Start := Clock;
         T.Receive (Rel, Msg, Timeout, Got);
         Late := (Clock - Start) - To_Time_Span (Timeout);
         if Late > Worst then
            Worst := Late;
         end if;
         Count := Count + 1;
      end loop;
      Put_Line ("  info  UC-18: worst return after timeout ="
                & Duration'Image (To_Duration (Worst) * 1000)
                & " ms over" & Natural'Image (Runs) & " runs");
      Check (not Got and then T.Pending (Rel) = 0,
             "UC-18: repeated timeouts leave queue unchanged");
      Check (Worst < Tolerance,
             "UC-18: returns within SNFR-2 tolerance (30 ms) after timeout");
   end;

   --  Message already waiting: returned right away, removed from queue.
   T.Try_Publish (Pub, (Id => 7, Value => 1.5), Delivered);
   Check (Delivered, "UC-18 setup: message published");
   declare
      Start   : constant Time := Clock;
      Elapsed : Time_Span;
   begin
      T.Receive (Rel, Msg, 0.5, Got);
      Elapsed := Clock - Start;
      Check (Got and then Msg.Id = 7,
             "UC-18: waiting message returned with Success = True");
      Check (T.Pending (Rel) = 0, "UC-18: message removed from queue");
      Check (Elapsed < Milliseconds (500),
             "UC-18: did not wait when a message was ready");
   end;

   --  Message arrives during the wait: returned before the timeout.
   declare
      task Late_Publisher;
      task body Late_Publisher is
         Ok : Boolean;
      begin
         delay 0.05;
         T.Try_Publish (Pub, (Id => 8, Value => 2.5), Ok);
      end Late_Publisher;

      Start   : constant Time := Clock;
      Elapsed : Time_Span;
   begin
      T.Receive (Rel, Msg, 1.0, Got);
      Elapsed := Clock - Start;
      Check (Got and then Msg.Id = 8,
             "UC-18: message arriving during the wait is returned");
      Check (Elapsed >= Milliseconds (40)
               and then Elapsed < Milliseconds (1_000),
             "UC-18: returned when the message arrived, before the timeout");
   end;

   --  UC-17: after draining Reliable, successful publication clears
   --  all rejection flags.
   T.Try_Publish
     (Pub, (Id => 101, Value => 1.0), Delivered, Rejections);

   Check (Delivered, "bitmap: delivery succeeds with capacity");
   Check (not Rejections (1) and then not Rejections (2),
          "bitmap: no subscriber rejected");

   --  UC-17: diagnostic bounds follow Max_Subscribers, and unused
   --  registration slots never report rejection.
   T_Unused.Create_Publisher (Pub_Unused);
   T_Unused.Create_Subscriber (Sub_Unused);

   T_Unused.Try_Publish
     (Pub_Unused,
      (Id => 200, Value => 2.0),
      Unused_Delivered,
      Unused_Failures);

   Check (Unused_Delivered, "unused slots: delivery succeeds");
   Check (not Unused_Failures (1)
          and then not Unused_Failures (2)
          and then not Unused_Failures (3),
          "unused slots: all failure flags clear");

   T_Unused.Try_Publish
     (Pub_Unused,
      (Id => 201, Value => 2.0),
      Unused_Delivered,
      Unused_Failures);

   Check (not Unused_Delivered,
          "unused slots: full reliable subscriber rejects");
   Check (Unused_Failures (1)
          and then not Unused_Failures (2)
          and then not Unused_Failures (3),
          "unused slots: only registered subscriber flagged");

   --  UC-17 / SFR-6: a full middle Reliable subscriber must not
   --  prevent delivery to later subscribers.
   T_Partial.Create_Publisher (Partial_Pub);
   T_Partial.Create_Subscriber (Partial_First);
   T_Partial.Create_Subscriber (Partial_Middle);
   T_Partial.Create_Subscriber (Partial_Last);

   --  Initially fill all three queues.
   T_Partial.Try_Publish
     (Partial_Pub,
      (Id => 300, Value => 3.0),
      Partial_Delivered,
      Partial_Failures);

   Check (Partial_Delivered, "partial: initial delivery succeeds");

   --  Drain the first and last queues, leaving the middle full.
   T_Partial.Receive (Partial_First, Msg);
   T_Partial.Receive (Partial_Last, Msg);

   --  Only the middle subscriber should reject this publication.
   T_Partial.Try_Publish
     (Partial_Pub,
      (Id => 301, Value => 3.1),
      Partial_Delivered,
      Partial_Failures);

   Check (not Partial_Delivered,
          "partial: full middle subscriber reports failure");

   Check (not Partial_Failures (1)
          and then Partial_Failures (2)
          and then not Partial_Failures (3),
          "partial: only middle subscriber flagged");

   Check (T_Partial.Pending (Partial_First) = 1
          and then T_Partial.Pending (Partial_Middle) = 1
          and then T_Partial.Pending (Partial_Last) = 1,
          "partial: all queues retain expected counts");

   --  Verify exactly which message each subscriber received.
   T_Partial.Receive (Partial_First, Msg);
   Check (Msg.Id = 301, "partial: first received new message");

   T_Partial.Receive (Partial_Middle, Msg);
   Check (Msg.Id = 300, "partial: middle preserved original message");

   T_Partial.Receive (Partial_Last, Msg);
   Check (Msg.Id = 301, "partial: last received despite middle failure");

   Check (T_Partial.Dropped (Partial_Middle) = 0,
          "partial: reliable subscriber dropped nothing");

   --  TODO (weeks 5-8): blocking Publish on a full Reliable queue, from a
   --  separate task, verified to unblock when the subscriber drains.
   --  TODO (weeks 9-12): load test, N publishers tasks, sustained
   --  overflow, assert Dropped (Rel) = 0 at the end. Always.

   New_Line;
   if Failures = 0 then
      Put_Line ("all passed");
   else
      Put_Line (Natural'Image (Failures) & " failure(s)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Topic_Tests;
