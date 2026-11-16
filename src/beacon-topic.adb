with Ada.Assertions;

package body Beacon.Topic is

   -------------------
   -- Bounded_Queue --
   -------------------

   protected body Bounded_Queue is

      entry Push (Msg : Message_Type)
        when Mode = Best_Effort or else not Ring.Is_Full (Q)
      is
         Dropped : Boolean;
      begin
         if Mode = Best_Effort then
            Ring.Push_Dropping_Oldest (Q, Msg, Dropped);
            if Dropped then
               Drops := Drops + 1;
            end if;
         else
            Ring.Push (Q, Msg);
         end if;
      end Push;

      procedure Try_Push (Msg : Message_Type; Accepted : out Boolean) is
         Dropped : Boolean;
      begin
         if Mode = Best_Effort then
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
      end Try_Push;

      entry Pop (Msg : out Message_Type) when not Ring.Is_Empty (Q) is
      begin
         Ring.Pop (Q, Msg);
      end Pop;

      procedure Try_Pop (Msg : out Message_Type; Success : out Boolean) is
      begin
         Success := not Ring.Is_Empty (Q);
         if Success then
            Ring.Pop (Q, Msg);
         end if;
      end Try_Pop;

      function Count return Natural is (Ring.Count (Q));
      function Drop_Count return Natural is (Drops);

   end Bounded_Queue;

   --------------
   -- Registry --
   --------------

   type Subscriber_Access is access all Subscriber;
   type Registry_Array is array (1 .. Max_Subscribers) of Subscriber_Access;

   protected Registry is
      procedure Add (S : not null Subscriber_Access);
      procedure Claim_Publisher (P : in out Publisher);
      procedure Freeze (Snapshot : out Registry_Array; Size : out Natural);
      function Count return Natural;
      function Has_Publisher return Boolean;
   private
      Members         : Registry_Array := [others => null];
      Registered      : Natural range 0 .. Max_Subscribers := 0;
      Publisher_Taken : Boolean := False;
      Closed          : Boolean := False;
   end Registry;

   protected body Registry is
      procedure Add (S : not null Subscriber_Access) is
      begin
         --  Preconditions alone cannot make a check and insertion atomic.
         if Closed or else Registered = Max_Subscribers or else S.Registered then
            raise Ada.Assertions.Assertion_Error with "subscriber registration rejected";
         end if;
         Registered := Registered + 1;
         Members (Registered) := S;
         S.Registered := True;
      end Add;

      procedure Claim_Publisher (P : in out Publisher) is
      begin
         if Publisher_Taken or else P.Created then
            raise Ada.Assertions.Assertion_Error with "publisher already created";
         end if;
         Publisher_Taken := True;
         P.Created := True;
      end Claim_Publisher;

      procedure Freeze (Snapshot : out Registry_Array; Size : out Natural) is
      begin
         Closed := True;
         Snapshot := Members;
         Size := Registered;
      end Freeze;

      function Count return Natural is (Registered);
      function Has_Publisher return Boolean is (Publisher_Taken);
   end Registry;

   ---------------
   -- Publisher --
   ---------------

   function Has_Publisher return Boolean is (Registry.Has_Publisher);
   function Is_Created (P : Publisher) return Boolean is (P.Created);

   procedure Create_Publisher (P : in out Publisher) is
   begin
      Registry.Claim_Publisher (P);
   end Create_Publisher;

   procedure Publish (P : Publisher; Msg : Message_Type) is
      pragma Unreferenced (P);  --  P is used only by the precondition
      Members : Registry_Array;
      Count   : Natural;
   begin
      --  Queue entries can block, so call them after releasing the registry.
      Registry.Freeze (Members, Count);
      for I in 1 .. Count loop
         Members (I).Queue.Push (Msg);
      end loop;
   end Publish;

   procedure Try_Publish
     (P         : Publisher;
      Msg       : Message_Type;
      Delivered : out Boolean)
   is
      pragma Unreferenced (P);
      Accepted : Boolean;
      Members  : Registry_Array;
      Count    : Natural;
   begin
      Registry.Freeze (Members, Count);
      Delivered := True;
      for I in 1 .. Count loop
         Members (I).Queue.Try_Push (Msg, Accepted);
         Delivered := Delivered and Accepted;
      end loop;
   end Try_Publish;

   ----------------
   -- Subscriber --
   ----------------

   function Subscriber_Count return Natural is (Registry.Count);
   function Is_Registered (S : Subscriber) return Boolean is (S.Registered);

   procedure Create_Subscriber (S : aliased in out Subscriber) is
   begin
      Registry.Add (S'Unchecked_Access);
   end Create_Subscriber;

   procedure Receive (S : in out Subscriber; Msg : out Message_Type) is
   begin
      S.Queue.Pop (Msg);
   end Receive;

   procedure Try_Receive
     (S       : in out Subscriber;
      Msg     : out Message_Type;
      Success : out Boolean) is
   begin
      S.Queue.Try_Pop (Msg, Success);
   end Try_Receive;

   function Pending (S : Subscriber) return Natural is (S.Queue.Count);
   function Dropped (S : Subscriber) return Natural is (S.Queue.Drop_Count);

end Beacon.Topic;
