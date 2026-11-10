with Ada.Real_Time;
package body Beacon.Topic is

   -------------------
   -- Bounded_Queue --
   -------------------

   protected body Bounded_Queue is

      procedure Configure (Mode : Delivery_Mode) is
      begin
         Current_Mode := Mode;
         Can_Push := True;
         Has_Data := False;
      end Configure;

      entry Push (Msg : Message_Type) when Can_Push is
         Dropped : Boolean;
      begin
         if Current_Mode = Best_Effort then
            Ring.Push_Dropping_Oldest (Q, Msg, Dropped);
            if Dropped then
               Drops := Drops + 1;
            end if;
         else
            Ring.Push (Q, Msg);
         end if;

         Can_Push := Current_Mode = Best_Effort or else not Ring.Is_Full (Q);
         Has_Data := not Ring.Is_Empty (Q);
      end Push;

      procedure Try_Push (Msg : Message_Type; Accepted : out Boolean) is
         Dropped : Boolean;
      begin
         if Current_Mode = Best_Effort then
            Ring.Push_Dropping_Oldest (Q, Msg, Dropped);
            if Dropped then
               Drops := Drops + 1;
            end if;
            Accepted := True;
         elsif Ring.Is_Full (Q) then
            Accepted := False;
         else
            Ring.Push (Q, Msg);
            Accepted := True;
         end if;

         Can_Push := Current_Mode = Best_Effort or else not Ring.Is_Full (Q);
         Has_Data := not Ring.Is_Empty (Q);
      end Try_Push;

      entry Pop (Msg : out Message_Type) when Has_Data is
      begin
         Ring.Pop (Q, Msg);
         Can_Push := Current_Mode = Best_Effort or else not Ring.Is_Full (Q);
         Has_Data := not Ring.Is_Empty (Q);
      end Pop;

      procedure Try_Pop (Msg : out Message_Type; Success : out Boolean) is
      begin
         Success := not Ring.Is_Empty (Q);
         if Success then
            Ring.Pop (Q, Msg);
         end if;
         Can_Push := Current_Mode = Best_Effort or else not Ring.Is_Full (Q);
         Has_Data := not Ring.Is_Empty (Q);
      end Try_Pop;

      function Count return Natural is (Ring.Count (Q));
      function Drop_Count return Natural is (Drops);

   end Bounded_Queue;

   Publisher_Taken : Boolean := False;

   ---------------
   -- Publisher --
   ---------------

   function Has_Publisher return Boolean is (Publisher_Taken);
   function Is_Created (P : Publisher) return Boolean is (P.Created);

   procedure Create_Publisher (P : in out Publisher) is
   begin
      Publisher_Taken := True;
      P.Created := True;
   end Create_Publisher;

   procedure Publish (P : Publisher; Msg : Message_Type) is
      pragma Unreferenced (P);  --  the precondition is the whole use
   begin
      for I in 1 .. Registered loop
         Slots (I).Push (Msg);
      end loop;
   end Publish;

   procedure Try_Publish
     (P         : Publisher;
      Msg       : Message_Type;
      Delivered : out Boolean)
   is
      pragma Unreferenced (P);
      Accepted : Boolean;
   begin
      Delivered := True;
      for I in 1 .. Registered loop
         Slots (I).Try_Push (Msg, Accepted);
         Delivered := Delivered and Accepted;
      end loop;
   end Try_Publish;

   procedure Try_Publish
     (P         : Publisher;
      Msg       : Message_Type;
      Delivered : out Boolean;
      Failures  : out Delivery_Failures)
   is
      pragma Unreferenced (P);
      Accepted : Boolean;
   begin
      Delivered := True;
      Failures := [others => False];

      for I in 1 .. Registered loop
         Slots (I).Try_Push (Msg, Accepted);
         Failures (I) := not Accepted;
         Delivered := Delivered and Accepted;
      end loop;
   end Try_Publish;

   ----------------
   -- Subscriber --
   ----------------

   function Subscriber_Count return Natural is (Registered);
   function Is_Registered (S : Subscriber) return Boolean is (S.Slot /= 0);

   procedure Create_Subscriber (S : in out Subscriber) is
      New_Index : constant Active_Slot_Index := Registered + 1; --  increment by 1
   begin
      Slots (New_Index).Configure (S.Mode);
      S.Slot := New_Index;
      Registered := New_Index;
   end Create_Subscriber;

   procedure Receive (S : in out Subscriber; Msg : out Message_Type) is
   begin
      Slots (S.Slot).Pop (Msg);
   end Receive;

   procedure Try_Receive
     (S       : in out Subscriber;
      Msg     : out Message_Type;
      Success : out Boolean) is
   begin
      Slots (S.Slot).Try_Pop (Msg, Success);
   end Try_Receive;

   procedure Receive
     (S       : in out Subscriber;
      Msg     : out Message_Type;
      Timeout : Duration;
      Success : out Boolean)
   is
      use Ada.Real_Time;
      Deadline : constant Time      := Clock + To_Time_Span (Timeout);
      Poll     : constant Time_Span := Milliseconds (1);
      Next     : Time;
   begin
      loop
         Try_Receive (S, Msg, Success);
         exit when Success or else Clock >= Deadline;

         Next := Clock + Poll;
         if Next > Deadline then
            Next := Deadline;
         end if;
         delay until Next;
      end loop;
   end Receive;

   function Pending (S : Subscriber) return Natural is
      (if S.Slot = 0 then 0 else Slots (S.Slot).Count);
   function Dropped (S : Subscriber) return Natural is
      (if S.Slot = 0 then 0 else Slots (S.Slot).Drop_Count);

end Beacon.Topic;
