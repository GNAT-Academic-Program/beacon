--  Beacon.Topic: one instantiation per message type.
--
--     package Telemetry_Topic is new Beacon.Topic
--       (Message_Type => Telemetry_Reading, Queue_Depth => 32);
--
--  Everything a publisher sends and a subscriber receives is a
--  Message_Type. There is no other path (design rule 1).
--
--  Static model (design rule 4): the instantiation owns a fixed table of
--  at most Max_Subscribers. Subscribers register at startup, before any
--  Publish. Registration is not task-safe by design; publishing is.
--
--  Single writer: one Publisher per instantiation. Create_Publisher
--  refuses a second one.
--
--  Runtime needs: protected types with entries, so light-tasking
--  (Ravenscar / Jorvik) or full. Not ZFP. On ZFP use Beacon.Queue directly.

with Beacon.Queue;

generic
   type Message_Type is private;
   Queue_Depth     : Positive;
   Max_Subscribers : Positive := 8;
package Beacon.Topic is

   type Publisher is limited private;
   type Subscriber (Mode : Delivery_Mode) is limited private;

   ---------------
   -- Publisher --
   ---------------

   function Has_Publisher return Boolean;
   function Is_Created (P : Publisher) return Boolean;

   procedure Create_Publisher (P : in out Publisher)
     with Pre  => not Has_Publisher and then not Is_Created (P),
          Post => Has_Publisher and then Is_Created (P);

   --  Delivers Msg to every registered subscriber, in registration order.
   --  Reliable subscriber with a full queue: blocks until it has room.
   --  Best_Effort subscriber with a full queue: drops its oldest, counts it.
   procedure Publish (P : Publisher; Msg : Message_Type)
     with Pre => Is_Created (P);

   --  Never waits for queue capacity.
   --  Reliable subscriber with a full queue: rejects Msg.
   --  Best_Effort subscriber: accepts Msg, dropping oldest if full.
   --  Partial delivery is intentional: other subscribers still receive Msg.
   --  Delivered is false if any Reliable subscriber rejected Msg, true otherwise.
   procedure Try_Publish
     (P         : Publisher;
      Msg       : Message_Type;
      Delivered : out Boolean)
     with Pre => Is_Created (P);

   --  Failure flags indexed by subscriber registration order
   --  The array size is fixed by Max_Subscribers at instantiation
   --  True means that the subscriber rejected Msg because the queue was full
   --  Unused registration slots remain false
   type Delivery_Failures is
      array (1 .. Max_Subscribers) of Boolean;

   --  Same delivery behavior as Try_Publish, with per-subscrier results.
   procedure Try_Publish
       (P            : Publisher;
         Msg         : Message_Type;
         Delivered   : out Boolean;
         Failures    : out Delivery_Failures)
       with Pre => Is_Created (P);

   ----------------
   -- Subscriber --
   ----------------

   function Subscriber_Count return Natural
     with Post => Subscriber_Count'Result <= Max_Subscribers;

   function Is_Registered (S : Subscriber) return Boolean;

   --  S must outlive every Publish: declare it at library level or in
   --  the scope that owns the whole run. No heap, so no copy is taken.
   procedure Create_Subscriber (S : aliased in out Subscriber)
     with Pre  => Subscriber_Count < Max_Subscribers
                  and then not Is_Registered (S),
          Post => Subscriber_Count = Subscriber_Count'Old + 1
                  and then Is_Registered (S);

   --  Blocks until a message is available.
   procedure Receive (S : in out Subscriber; Msg : out Message_Type)
     with Pre => Is_Registered (S);

   procedure Try_Receive
     (S       : in out Subscriber;
      Msg     : out Message_Type;
      Success : out Boolean)
     with Pre => Is_Registered (S);

   --  Messages waiting in S's queue.
   function Pending (S : Subscriber) return Natural;

   --  Messages S has dropped so far. Always 0 for a Reliable subscriber;
   --  that is the checkable form of design rule 2.
   function Dropped (S : Subscriber) return Natural;

private

   package Ring is new Beacon.Queue (Message_Type, Queue_Depth);

   protected type Bounded_Queue (Mode : Delivery_Mode) is
      --  Barrier: Best_Effort always open; Reliable open when not full.
      entry Push (Msg : Message_Type);
      procedure Try_Push (Msg : Message_Type; Accepted : out Boolean);
      entry Pop (Msg : out Message_Type);
      procedure Try_Pop (Msg : out Message_Type; Success : out Boolean);
      function Count return Natural;
      function Drop_Count return Natural;
   private
      Q     : Ring.Queue_Type := Ring.Empty_Queue;
      Drops : Natural := 0;
   end Bounded_Queue;

   type Subscriber (Mode : Delivery_Mode) is limited record
      Queue      : Bounded_Queue (Mode);
      Registered : Boolean := False;
   end record;

   type Publisher is limited record
      Created : Boolean := False;
   end record;

end Beacon.Topic;
